-- ============================================================================
-- Apple Expert · Inventory integration 1/4 · tracking modes and the online
-- order reservation lifecycle
-- ----------------------------------------------------------------------------
-- Builds on P1 (20261023120000) and the GRN / purchasing migrations
-- (20261028120000, 20261028160000). Those two are NOT rewritten: whether they
-- ran on every environment cannot be proven from this repository, so this work
-- is forward-only.
--
-- WHAT THE STOCK NUMBER MEANS FROM HERE ON
--
--   products.stock / product_variants.stock = sellable stock physically on hand
--   at MAIN_SHOP, including units held for an online order.
--
--   available = on hand - active reservations
--
--   20261028120000 took stock when an order was PLACED, with no expiry. Replaced
--   here by the approved lifecycle:
--
--     place_order        -> reservation only. The number does not move.
--     48 h unconfirmed   -> order cancelled, reservation released. Number unmoved.
--     confirmed/processing -> never expires.
--     cancel before ship -> reservation released. Number unmoved.
--     FIRST shipped OR delivered -> reservation consumed and the ledger's 'sale'
--                                   row written, exactly once per order line.
--     cancel after ship  -> stock is NOT restored. Goods come back through a
--                           customer return (migration 3/4).
--
-- ORDERS THAT EXISTED BEFORE THIS MIGRATION (orders.stock_state)
--   status shipped / delivered  -> legacy_done    never deducted again
--   status cancelled / refunded -> legacy_closed
--   anything else               -> legacy_open    not reserved retroactively; on
--     first shipment stock is deducted if sufficient, otherwise the line is
--     flagged in stock_reconciliation_flags for a person to resolve.
--
-- LOCK ORDER (every stock path, so child rows are never locked before parents)
--   document (order / PO / sale / supplier) -> products in sorted id order ->
--   variants -> reservations and units.
--   One exception, safe because it never waits: the expiry sweep holds product
--   locks and takes order rows with FOR UPDATE SKIP LOCKED.
--
-- DECISIONS (documented, not silent)
--   * Tracking mode is explicit, per stock holder. It is no longer inferred from
--     "has this product ever received a unit". Every existing product starts as
--     'quantity': nothing is converted silently. Moving to 'unit' needs zero
--     stock, which is what the physical count cutover produces.
--   * categories.default_tracking_mode applies only to products created later.
--   * Reservation limits per customer are configurable and default to NO LIMIT.
--     The number is a business decision that has not been made.
--   * No pg_cron / pg_net. Expiry is enforced three ways that need no extension:
--     availability ignores overdue reservations, every stock-taking path sweeps
--     overdue orders for the products it touches, and
--     public.expire_pending_orders() can be called by staff or by an external
--     scheduler through the expire-reservations edge function.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Pre-flight
-- ----------------------------------------------------------------------------
do $$
declare
  v_old integer;
begin
  if to_regclass('public.suppliers') is null or to_regclass('public.inventory_units') is null then
    raise exception 'pre-flight: apply 20261028120000 and 20261028160000 first';
  end if;

  -- Orders placed under the take-at-placement code have already moved stock.
  -- Their meaning cannot be guessed: a person must resolve them first. Put the
  -- store in maintenance mode while pushing, so none can appear in between.
  select count(*) into v_old from public.orders where stock_state is not null;
  if v_old > 0 then
    raise exception 'pre-flight: % orders took stock under the previous code. Reconcile them before applying this migration.', v_old;
  end if;
end
$$;


-- ----------------------------------------------------------------------------
-- 1. Audit trail for inventory and purchasing changes the ledger does not cover
-- ----------------------------------------------------------------------------
create table public.inventory_audit_log (
  id           uuid primary key default gen_random_uuid(),
  entity_type  text not null,
  entity_id    text not null,
  action       text not null,
  actor_id     uuid references public.profiles (id) on delete set null,
  before_data  jsonb,
  after_data   jsonb,
  note         text,
  created_at   timestamptz not null default now()
);

create index inventory_audit_log_entity_idx on public.inventory_audit_log (entity_type, entity_id, created_at desc);

comment on table public.inventory_audit_log is
  'Append-only. Written only by SECURITY DEFINER functions. Owner/admin read: rows may carry costs and balances.';

alter table public.inventory_audit_log enable row level security;
create policy "inventory_audit_log admin read" on public.inventory_audit_log
  for select to authenticated using (private.has_role('admin'));

revoke all on public.inventory_audit_log from anon;
revoke insert, update, delete, truncate on public.inventory_audit_log from authenticated, service_role;
grant select on public.inventory_audit_log to authenticated;

create or replace function private.audit(
  p_entity_type text,
  p_entity_id   text,
  p_action      text,
  p_before      jsonb,
  p_after       jsonb,
  p_note        text
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.inventory_audit_log (entity_type, entity_id, action, actor_id, before_data, after_data, note)
  values (p_entity_type, p_entity_id, p_action, (select auth.uid()), p_before, p_after, p_note);
$$;

-- Stable hash of a request's content: jsonb stores keys in a canonical order.
create or replace function private.fingerprint(p_payload jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(pg_catalog.sha256(pg_catalog.convert_to(p_payload::text, 'UTF8')), 'hex')
$$;

revoke all on function private.audit(text, text, text, jsonb, jsonb, text) from public, anon, authenticated, service_role;
revoke all on function private.fingerprint(jsonb) from public, anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 2. Locations. MAIN_SHOP is sellable; QUARANTINE never is.
-- ----------------------------------------------------------------------------
create table public.inventory_locations (
  code         text primary key check (code ~ '^[A-Z][A-Z0-9_]{1,30}$'),
  name         text not null,
  is_sellable  boolean not null
);

insert into public.inventory_locations (code, name, is_sellable) values
  ('MAIN_SHOP',  'Main shop',  true),
  ('QUARANTINE', 'Quarantine', false);

alter table public.inventory_locations enable row level security;
create policy "inventory_locations staff read" on public.inventory_locations
  for select to authenticated using (private.has_role('staff'));

revoke all on public.inventory_locations from anon;
revoke insert, update, delete, truncate on public.inventory_locations from authenticated, service_role;
grant select on public.inventory_locations to authenticated;


-- ----------------------------------------------------------------------------
-- 3. Configurable policy. Staff read (the counter must know its limit).
-- ----------------------------------------------------------------------------
create table public.inventory_policy (
  id                                boolean primary key default true check (id),
  -- NULL = no limit configured. REQUIRES BUSINESS APPROVAL: see docs.
  max_reserved_units_per_customer   integer check (max_reserved_units_per_customer is null or max_reserved_units_per_customer > 0),
  max_active_orders_per_customer    integer check (max_active_orders_per_customer is null or max_active_orders_per_customer > 0),
  -- Basis points of the bill a staff member may discount without approval.
  -- Default 0 is the safe setting, not a business decision: every staff discount
  -- goes to an owner/admin until the business chooses a threshold.
  staff_max_discount_bps            integer not null default 0 check (staff_max_discount_bps between 0 and 10000),
  updated_by                        uuid references public.profiles (id) on delete set null,
  updated_at                        timestamptz not null default now()
);

insert into public.inventory_policy (id) values (true);

alter table public.inventory_policy enable row level security;
create policy "inventory_policy staff read" on public.inventory_policy
  for select to authenticated using (private.has_role('staff'));

revoke all on public.inventory_policy from anon;
revoke insert, update, delete, truncate on public.inventory_policy from authenticated, service_role;
grant select on public.inventory_policy to authenticated;

create or replace function public.admin_save_inventory_policy(
  p_max_reserved_units_per_customer integer,
  p_max_active_orders_per_customer  integer,
  p_staff_max_discount_bps          integer,
  p_note                            text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note   text := btrim(coalesce(p_note, ''));
  v_before public.inventory_policy;
  v_after  public.inventory_policy;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;
  if p_staff_max_discount_bps is null or p_staff_max_discount_bps not between 0 and 10000 then
    raise exception 'invalid_policy: the staff discount limit must be from 0%% to 100%%' using errcode = '22023';
  end if;
  if (p_max_reserved_units_per_customer is not null and p_max_reserved_units_per_customer < 1)
     or (p_max_active_orders_per_customer is not null and p_max_active_orders_per_customer < 1) then
    raise exception 'invalid_policy: a customer limit must be at least 1, or blank for no limit' using errcode = '22023';
  end if;

  select * into v_before from public.inventory_policy where id for update;

  update public.inventory_policy
     set max_reserved_units_per_customer = p_max_reserved_units_per_customer,
         max_active_orders_per_customer = p_max_active_orders_per_customer,
         staff_max_discount_bps = p_staff_max_discount_bps,
         updated_by = (select auth.uid()),
         updated_at = now()
   where id
  returning * into v_after;

  perform private.audit('inventory_policy', 'singleton', 'update', to_jsonb(v_before), to_jsonb(v_after), v_note);
  return to_jsonb(v_after);
end;
$$;

revoke all on function public.admin_save_inventory_policy(integer, integer, integer, text) from public, anon, service_role;
grant execute on function public.admin_save_inventory_policy(integer, integer, integer, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 4. Tracking mode: per stock holder, explicit, protected
-- ----------------------------------------------------------------------------
alter table public.categories
  add column default_tracking_mode text not null default 'quantity'
    constraint categories_default_tracking_mode_check check (default_tracking_mode in ('quantity', 'unit'));

alter table public.products
  add column tracking_mode text not null default 'quantity'
    constraint products_tracking_mode_check check (tracking_mode in ('quantity', 'unit'));

-- NULL = follow the product. Only meaningful on an own-stock variant: variants
-- sharing a pool share its mode, or the pool's number could not be reconciled.
alter table public.product_variants
  add column tracking_mode text
    constraint product_variants_tracking_mode_check check (tracking_mode is null or tracking_mode in ('quantity', 'unit'));

comment on column public.products.tracking_mode is
  'quantity = a number only; unit = every item is a barcoded inventory_units row. Changed only by admin_set_tracking_mode().';
comment on column public.categories.default_tracking_mode is
  'Mode for products created later in this category. Never applied to existing products.';

-- Approved rule: Apple devices are tracked individually. Applies to new products.
-- Also emitted by scripts/generate-seed.mjs, because locally migrations run
-- before the seed and this update would find no rows.
update public.categories set default_tracking_mode = 'unit'
 where slug in ('iphone', 'ipad', 'mac', 'watch', 'airpods');

-- SECURITY INVOKER on purpose: current_user is the API role for a direct request
-- and the function owner inside admin_set_tracking_mode().
create or replace function private.guard_tracking_mode()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated', 'service_role') then
    if tg_op = 'INSERT' then
      if tg_table_name = 'products' then
        select c.default_tracking_mode into new.tracking_mode
          from public.categories c where c.id = new.category_id;
        new.tracking_mode := coalesce(new.tracking_mode, 'quantity');
      else
        new.tracking_mode := null;
      end if;
    elsif new.tracking_mode is distinct from old.tracking_mode then
      raise exception 'tracking_mode_locked: change the tracking mode from the product editor'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_tracking_mode() from public, anon, authenticated, service_role;

create trigger products_guard_tracking_mode
  before insert or update of tracking_mode on public.products
  for each row execute function private.guard_tracking_mode();

create trigger product_variants_guard_tracking_mode
  before insert or update of tracking_mode on public.product_variants
  for each row execute function private.guard_tracking_mode();


-- ----------------------------------------------------------------------------
-- 5. Units: quarantine status, location, and an IMEI lifecycle
-- ----------------------------------------------------------------------------
alter table public.inventory_units
  add column location_code text not null default 'MAIN_SHOP' references public.inventory_locations (code) on delete restrict,
  add column reentry_of_unit_id uuid references public.inventory_units (id) on delete restrict;

alter table public.inventory_units drop constraint inventory_units_status_check;
alter table public.inventory_units
  add constraint inventory_units_status_check
  check (status in ('in_stock', 'reserved', 'sold', 'written_off', 'returned_to_supplier', 'quarantined')),
  add constraint inventory_units_location_matches_status
  check ((status = 'quarantined') = (location_code = 'QUARANTINE'));

-- A serial may recur over a device's life (written off by mistake, repaired,
-- bought back), so history keeps every row. Only one row may be physically here.
drop index public.inventory_units_serial_key;
create unique index inventory_units_active_serial_key on public.inventory_units (serial_number)
  where serial_number is not null and status in ('in_stock', 'reserved', 'quarantined');
create index inventory_units_serial_history_idx on public.inventory_units (serial_number, created_at desc)
  where serial_number is not null;

comment on index public.inventory_units_active_serial_key is
  'Two units with one IMEI can never both be in the shop. Earlier rows of the same device are kept as history.';

-- Every unit status change is recorded, whichever function made it.
create or replace function private.log_unit_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.audit('inventory_unit', new.id::text, 'status',
                        jsonb_build_object('status', old.status),
                        jsonb_build_object('status', new.status, 'order_id', new.order_id,
                                           'pos_sale_id', new.pos_sale_id),
                        new.status_note);
  return null;
end;
$$;

revoke all on function private.log_unit_status() from public, anon, authenticated, service_role;

create trigger inventory_units_log_status
  after update of status on public.inventory_units
  for each row
  when (old.status is distinct from new.status)
  execute function private.log_unit_status();


-- ----------------------------------------------------------------------------
-- 6. Ledger: new reasons, and one 'sale' row per order line at the database level
-- ----------------------------------------------------------------------------
alter table public.inventory_movements drop constraint inventory_movements_reason_check;
alter table public.inventory_movements
  add constraint inventory_movements_reason_check
  check (reason in ('seed', 'restock', 'sale', 'return', 'adjustment', 'damage', 'transfer',
                    'stock_count', 'correction', 'opening_balance', 'supplier_return',
                    'supplier_return_reversal', 'quarantine', 'quarantine_release'));

alter table public.inventory_movements
  add column order_item_id uuid references public.order_items (id) on delete set null;

create unique index inventory_movements_order_item_sale_key
  on public.inventory_movements (order_item_id)
  where reason = 'sale' and order_item_id is not null;

comment on index public.inventory_movements_order_item_sale_key is
  'Online stock consumption is recorded exactly once per order line, whatever the application does.';


-- ----------------------------------------------------------------------------
-- 7. Orders and reservations
-- ----------------------------------------------------------------------------
alter table public.orders drop constraint if exists orders_stock_state_check;

alter table public.orders
  add column reservation_expires_at timestamptz,
  add column request_id uuid,
  add column request_fingerprint text;

-- Set before the NOT NULL below. The update trigger would rewrite updated_at on
-- every historical order, which would falsify when each was last touched.
alter table public.orders disable trigger orders_set_updated_at;
update public.orders
   set stock_state = case
         when status in ('shipped', 'delivered') then 'legacy_done'
         when status in ('cancelled', 'refunded') then 'legacy_closed'
         else 'legacy_open'
       end;
alter table public.orders enable trigger orders_set_updated_at;

alter table public.orders
  alter column stock_state set default 'legacy_open',
  alter column stock_state set not null,
  add constraint orders_stock_state_check check (stock_state in (
    'reserved', 'released', 'expired', 'consumed',
    'legacy_open', 'legacy_closed', 'legacy_done', 'needs_reconciliation'));

comment on column public.orders.stock_state is
  'reserved: holds stock, number unmoved. released/expired: reservation given up. consumed: stock deducted on first shipment (never twice). legacy_*: placed before reservations existed. needs_reconciliation: a legacy line could not be deducted; see stock_reconciliation_flags.';
comment on column public.orders.reservation_expires_at is
  'Set only while the order is pending and reserved. Confirmed and processing orders have none, so they never expire.';

-- Scoped to the customer, so one account can never read another's request id.
create unique index orders_profile_request_key on public.orders (profile_id, request_id)
  where request_id is not null;
create index orders_reservation_due_idx on public.orders (reservation_expires_at)
  where status = 'pending' and stock_state = 'reserved';

alter table public.order_items
  add column stock_consumed_at timestamptz,
  add column returned_quantity integer not null default 0
    constraint order_items_returned_quantity_check check (returned_quantity >= 0);

alter table public.order_items
  add constraint order_items_returned_within_quantity check (returned_quantity <= quantity);

create table public.stock_reservations (
  id                 uuid primary key default gen_random_uuid(),
  order_id           uuid not null references public.orders (id) on delete restrict,
  order_item_id      uuid not null references public.order_items (id) on delete restrict,
  product_id         text not null references public.products (id) on delete restrict,
  -- The variant bought (NULL if the product has none).
  variant_id         uuid references public.product_variants (id) on delete restrict,
  -- Whose number the reservation holds: an own-stock variant, or NULL for the
  -- product's shared pool. Stored so availability never re-derives it.
  holder_variant_id  uuid references public.product_variants (id) on delete restrict,
  quantity           integer not null check (quantity > 0),
  status             text not null default 'active'
                     check (status in ('active', 'released', 'expired', 'consumed')),
  expires_at         timestamptz,
  created_at         timestamptz not null default now(),
  closed_at          timestamptz,
  constraint stock_reservations_closed check ((status = 'active') = (closed_at is null))
);

create unique index stock_reservations_active_item_key on public.stock_reservations (order_item_id)
  where status = 'active';
create index stock_reservations_holder_idx on public.stock_reservations (product_id, holder_variant_id)
  where status = 'active';
create index stock_reservations_order_idx on public.stock_reservations (order_id);

comment on table public.stock_reservations is
  'Online-order holds. Reduce availability, not the stock number. Written only by SECURITY DEFINER functions; staff read.';

alter table public.stock_reservations enable row level security;
create policy "stock_reservations staff read" on public.stock_reservations
  for select to authenticated using (private.has_role('staff'));

revoke all on public.stock_reservations from anon;
revoke insert, update, delete, truncate on public.stock_reservations from authenticated, service_role;
grant select on public.stock_reservations to authenticated;

create table public.stock_reconciliation_flags (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references public.orders (id) on delete restrict,
  order_item_id  uuid not null references public.order_items (id) on delete restrict,
  product_id     text references public.products (id) on delete set null,
  variant_id     uuid references public.product_variants (id) on delete set null,
  quantity       integer not null check (quantity > 0),
  reason         text not null,
  resolved_at    timestamptz,
  resolved_by    uuid references public.profiles (id) on delete set null,
  resolution_note text check (resolution_note is null or length(resolution_note) <= 500),
  created_at     timestamptz not null default now(),
  constraint stock_reconciliation_flags_one unique (order_item_id),
  constraint stock_reconciliation_flags_resolved check ((resolved_at is null) = (resolution_note is null))
);

create index stock_reconciliation_flags_open_idx on public.stock_reconciliation_flags (created_at desc)
  where resolved_at is null;

comment on table public.stock_reconciliation_flags is
  'Pre-rollout order lines that shipped when stock could not cover them. Nothing is deducted or guessed: a person decides.';

alter table public.stock_reconciliation_flags enable row level security;
create policy "stock_reconciliation_flags staff read" on public.stock_reconciliation_flags
  for select to authenticated using (private.has_role('staff'));

revoke all on public.stock_reconciliation_flags from anon;
revoke insert, update, delete, truncate on public.stock_reconciliation_flags from authenticated, service_role;
grant select on public.stock_reconciliation_flags to authenticated;

-- Orders are created only by place_order, which is SECURITY DEFINER. A raw admin
-- INSERT could fabricate a line whose cancellation raised stock.
revoke insert on public.orders, public.order_items from authenticated;


-- ----------------------------------------------------------------------------
-- 8. Helpers
-- ----------------------------------------------------------------------------
create or replace function private.reservation_window()
returns interval
language sql
immutable
set search_path = ''
as $$ select interval '48 hours' $$;

-- Who holds the number: an own-stock variant's id, or NULL for the product pool.
create or replace function private.stock_holder(p_product_id text, p_variant_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select v.id from public.product_variants v
   where v.id = p_variant_id and v.product_id = p_product_id and v.stock is not null
$$;

create or replace function private.tracking_mode_of(p_product_id text, p_variant_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when v.stock is not null then coalesce(v.tracking_mode, p.tracking_mode) else p.tracking_mode end
    from public.products p
    left join public.product_variants v on v.id = p_variant_id and v.product_id = p.id
   where p.id = p_product_id
$$;

-- Active holds on one number. Overdue ones no longer count, so a late sweep can
-- never make stock look unavailable.
create or replace function private.reserved_quantity(p_product_id text, p_holder uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(r.quantity), 0)::integer
    from public.stock_reservations r
   where r.product_id = p_product_id
     and r.holder_variant_id is not distinct from p_holder
     and r.status = 'active'
     and (r.expires_at is null or r.expires_at > now())
$$;

-- What can be sold of exactly this product + variant right now.
--   unit mode:     shelf units of that exact variant (plus overdue holds)
--   quantity mode: the holder's number minus holds on it
create or replace function private.available_quantity(p_product_id text, p_variant_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_variant public.product_variants;
  v_holder  uuid;
  v_count   integer;
begin
  select * into v_product from public.products where id = p_product_id;
  if not found then
    return 0;
  end if;

  if p_variant_id is not null then
    select * into v_variant from public.product_variants where id = p_variant_id and product_id = p_product_id;
    if not found then
      return 0;
    end if;
    if v_variant.stock is not null then
      v_holder := v_variant.id;
    end if;
  end if;

  if private.tracking_mode_of(p_product_id, p_variant_id) = 'unit' then
    select count(*)::integer into v_count
      from public.inventory_units u
     where u.product_id = p_product_id
       and u.variant_id is not distinct from p_variant_id
       and (u.status = 'in_stock'
            or (u.status = 'reserved' and exists (
                  select 1 from public.stock_reservations r
                   where r.order_item_id = u.order_item_id and r.status = 'active' and r.expires_at <= now())));
    return v_count;
  end if;

  return greatest(
    (case when v_holder is null then v_product.stock else v_variant.stock end)
      - private.reserved_quantity(p_product_id, v_holder),
    0);
end;
$$;

-- Product row first, in sorted order, so two multi-product operations can never
-- wait on each other. Anything that later inserts a child row already holds the
-- parent, which is what closes the KEY SHARE -> FOR UPDATE deadlock.
create or replace function private.lock_products(p_product_ids text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text;
begin
  for v_id in
    select distinct x from unnest(p_product_ids) as t(x) where x is not null order by x
  loop
    perform 1 from public.products p where p.id = v_id for update;
  end loop;
end;
$$;

-- Expires overdue pending orders touching these products (NULL = any), then
-- leaves the products locked. All products involved are locked sorted BEFORE any
-- order is cancelled, and order rows are taken with SKIP LOCKED, so this can
-- neither deadlock with a status change nor wait for one.
create or replace function private.sweep_and_lock(p_product_ids text[], p_limit integer default 50)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_due      uuid[];
  v_involved text[];
  v_id       uuid;
  v_count    integer := 0;
begin
  select array_agg(d.id) into v_due
    from (
      select o.id
        from public.orders o
       where o.status = 'pending'
         and o.stock_state = 'reserved'
         and o.reservation_expires_at <= now()
         and (p_product_ids is null or exists (
               select 1 from public.order_items i
                where i.order_id = o.id and i.product_id = any (p_product_ids)))
       order by o.reservation_expires_at
       limit p_limit
    ) d;

  select array_agg(i.product_id) into v_involved
    from public.order_items i
   where i.order_id = any (coalesce(v_due, '{}'::uuid[])) and i.product_id is not null;

  perform private.lock_products(coalesce(p_product_ids, '{}'::text[]) || coalesce(v_involved, '{}'::text[]));

  foreach v_id in array coalesce(v_due, '{}'::uuid[]) loop
    perform 1 from public.orders o
      where o.id = v_id and o.status = 'pending' and o.stock_state = 'reserved'
        and o.reservation_expires_at <= now()
      for update skip locked;
    if found then
      update public.orders set status = 'cancelled' where id = v_id;
      insert into public.order_events (order_id, from_status, to_status, actor_id, note)
      values (v_id, 'pending', 'cancelled', null,
              'Not confirmed within 48 hours: the reservation expired and the stock was released.');
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

-- The storefront's price precedence, used by online orders and the counter.
create or replace function private.resolve_price(p_product_id text, p_variant_id uuid, p_tier text)
returns table (price_id uuid, price_cents bigint, tier_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_variant_id is not null then
    return query select * from private.live_price(p_product_id, p_variant_id, p_tier);
    if found then return; end if;
    if p_tier <> 'retail' then
      return query select * from private.live_price(p_product_id, p_variant_id, 'retail');
      if found then return; end if;
    end if;
  end if;
  return query select * from private.live_price(p_product_id, null, p_tier);
  if found then return; end if;
  if p_tier <> 'retail' then
    return query select * from private.live_price(p_product_id, null, 'retail');
  end if;
end;
$$;

-- Replaced signature: adds the order line, and refuses to eat into reservations.
drop function if exists private.move_stock(text, uuid, integer, text, text, uuid, uuid, uuid);

/*
 * The one place unit- and order-driven stock changes happen. Same order as
 * admin_set_stock(): lock product, then variant -> ledger row -> stock.
 */
create or replace function private.move_stock(
  p_product_id    text,
  p_variant_id    uuid,
  p_delta         integer,
  p_reason        text,
  p_note          text,
  p_order_id      uuid,
  p_grn_id        uuid,
  p_pos_sale_id   uuid,
  p_order_item_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product  public.products;
  v_variant  public.product_variants;
  v_holder   uuid := null;
  v_before   integer;
  v_after    integer;
  v_reserved integer;
begin
  select * into v_product from public.products where id = p_product_id for update;
  if not found then
    raise exception 'unknown_product: %', coalesce(p_product_id, '(missing)') using errcode = 'P0001';
  end if;

  if p_variant_id is not null then
    select * into v_variant from public.product_variants
     where id = p_variant_id and product_id = p_product_id
     for update;
    if not found then
      raise exception 'variant_product_mismatch: that variant does not belong to %', p_product_id using errcode = 'P0001';
    end if;
    if v_variant.stock is not null then
      v_holder := v_variant.id;
    end if;
  end if;

  v_before := case when v_holder is null then v_product.stock else v_variant.stock end;
  if p_delta = 0 then
    return v_before;
  end if;

  v_after := v_before + p_delta;
  if v_after < 0 then
    raise exception 'insufficient_stock: % (requested %, available %)', p_product_id, -p_delta, v_before
      using errcode = 'P0001';
  end if;
  if v_after > 100000 then
    raise exception 'invalid_quantity: stock cannot exceed 100000' using errcode = '22023';
  end if;

  -- Stock promised to an online order cannot leave by any other door. A sale
  -- that consumes a reservation closes the reservation before calling this.
  if p_delta < 0 then
    v_reserved := private.reserved_quantity(p_product_id, v_holder);
    if v_after < v_reserved then
      raise exception 'stock_reserved: % has % held for online orders; only % can be taken',
        p_product_id, v_reserved, greatest(v_before - v_reserved, 0)
        using errcode = 'P0001';
    end if;
  end if;

  insert into public.inventory_movements
    (product_id, variant_id, delta, reason, order_id, actor_id, note,
     quantity_before, quantity_after, grn_id, pos_sale_id, order_item_id)
  values
    (p_product_id, v_holder, p_delta, p_reason, p_order_id, (select auth.uid()), p_note,
     v_before, v_after, p_grn_id, p_pos_sale_id, p_order_item_id);

  if v_holder is null then
    update public.products set stock = v_after where id = p_product_id;
  else
    update public.product_variants set stock = v_after where id = v_holder;
  end if;

  return v_after;
end;
$$;

drop function if exists private.reserve_order_line(uuid, text, uuid, text, uuid, integer);
drop function if exists private.is_unit_tracked(text);

/*
 * Holds stock for one order line. The number does not move. For a unit-tracked
 * item the oldest shelf units of that exact variant are held too (FIFO).
 * The caller already holds the product lock.
 */
create or replace function private.reserve_order_line(
  p_order_id   uuid,
  p_item_id    uuid,
  p_product_id text,
  p_variant_id uuid,
  p_quantity   integer,
  p_expires_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_available integer := private.available_quantity(p_product_id, p_variant_id);
  v_taken     integer;
begin
  if p_quantity > v_available then
    raise exception 'insufficient_stock: % (requested %, available %)', p_product_id, p_quantity, v_available
      using errcode = 'P0001';
  end if;

  insert into public.stock_reservations
    (order_id, order_item_id, product_id, variant_id, holder_variant_id, quantity, expires_at)
  values
    (p_order_id, p_item_id, p_product_id, p_variant_id,
     private.stock_holder(p_product_id, p_variant_id), p_quantity, p_expires_at);

  if private.tracking_mode_of(p_product_id, p_variant_id) = 'unit' then
    with picked as (
      select u.id
        from public.inventory_units u
       where u.product_id = p_product_id
         and u.variant_id is not distinct from p_variant_id
         and u.status = 'in_stock'
       order by u.received_on, u.fifo_seq
       limit p_quantity
       for update
    )
    update public.inventory_units u
       set status = 'reserved', order_id = p_order_id, order_item_id = p_item_id,
           status_changed_at = now(), status_note = null
      from picked
     where u.id = picked.id;
    get diagnostics v_taken = row_count;

    if v_taken < p_quantity then
      raise exception 'insufficient_stock: % (requested %, available %)', p_product_id, p_quantity, v_taken
        using errcode = 'P0001';
    end if;
  end if;
end;
$$;

-- Gives a line's hold back. Number unmoved: it never left.
create or replace function private.release_order_line(p_item_id uuid, p_close_status text, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.stock_reservations
     set status = p_close_status, closed_at = now(), expires_at = null
   where order_item_id = p_item_id and status = 'active';

  update public.inventory_units
     set status = 'in_stock', order_id = null, order_item_id = null,
         status_changed_at = now(), status_note = p_note
   where order_item_id = p_item_id and status = 'reserved';
end;
$$;

-- Turns a line's hold into a sale: exactly once. The reservation is closed first,
-- so move_stock does not count it against the sale that consumes it.
create or replace function private.consume_order_line(p_order_number text, p_item public.order_items)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_item.stock_consumed_at is not null then
    return;
  end if;

  update public.stock_reservations
     set status = 'consumed', closed_at = now(), expires_at = null
   where order_item_id = p_item.id and status = 'active';
  if not found then
    raise exception 'reservation_missing: a line on order % holds no stock', p_order_number using errcode = 'P0001';
  end if;

  update public.inventory_units
     set status = 'sold', status_changed_at = now()
   where order_item_id = p_item.id and status = 'reserved';

  perform private.move_stock(p_item.product_id, p_item.variant_id, -p_item.quantity, 'sale',
                             'Online order ' || p_order_number, p_item.order_id, null, null, p_item.id);

  update public.order_items set stock_consumed_at = now() where id = p_item.id;
end;
$$;

-- A pre-rollout line on its first shipment: deduct if stock covers it, otherwise
-- flag it for a person. Never raises for lack of stock: the goods have gone, and
-- refusing the status change would not bring them back. Returns false if flagged.
create or replace function private.consume_legacy_line(p_order_number text, p_item public.order_items)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
begin
  if p_item.stock_consumed_at is not null then
    return true;
  end if;

  if p_item.product_id is null then
    v_reason := 'The product no longer exists.';
  elsif private.available_quantity(p_item.product_id, p_item.variant_id) < p_item.quantity then
    v_reason := 'Stock on record could not cover this line when it shipped.';
  end if;

  if v_reason is not null then
    insert into public.stock_reconciliation_flags (order_id, order_item_id, product_id, variant_id, quantity, reason)
    values (p_item.order_id, p_item.id, p_item.product_id, p_item.variant_id, p_item.quantity, v_reason)
    on conflict (order_item_id) do nothing;
    return false;
  end if;

  if private.tracking_mode_of(p_item.product_id, p_item.variant_id) = 'unit' then
    with picked as (
      select u.id
        from public.inventory_units u
       where u.product_id = p_item.product_id
         and u.variant_id is not distinct from p_item.variant_id
         and u.status = 'in_stock'
       order by u.received_on, u.fifo_seq
       limit p_item.quantity
       for update
    )
    update public.inventory_units u
       set status = 'sold', order_id = p_item.order_id, order_item_id = p_item.id,
           status_changed_at = now(), status_note = 'Assigned when pre-rollout order ' || p_order_number || ' shipped'
      from picked
     where u.id = picked.id;
  end if;

  perform private.move_stock(p_item.product_id, p_item.variant_id, -p_item.quantity, 'sale',
                             'Pre-rollout online order ' || p_order_number, p_item.order_id, null, null, p_item.id);

  update public.order_items set stock_consumed_at = now() where id = p_item.id;
  return true;
end;
$$;

revoke all on function private.reservation_window() from public, anon, authenticated, service_role;
revoke all on function private.stock_holder(text, uuid) from public, anon, authenticated, service_role;
revoke all on function private.tracking_mode_of(text, uuid) from public, anon, authenticated, service_role;
revoke all on function private.reserved_quantity(text, uuid) from public, anon, authenticated, service_role;
revoke all on function private.available_quantity(text, uuid) from public, anon, authenticated, service_role;
revoke all on function private.lock_products(text[]) from public, anon, authenticated, service_role;
revoke all on function private.sweep_and_lock(text[], integer) from public, anon, authenticated, service_role;
revoke all on function private.resolve_price(text, uuid, text) from public, anon, authenticated, service_role;
revoke all on function private.move_stock(text, uuid, integer, text, text, uuid, uuid, uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.reserve_order_line(uuid, uuid, text, uuid, integer, timestamptz) from public, anon, authenticated, service_role;
revoke all on function private.release_order_line(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function private.consume_order_line(text, public.order_items) from public, anon, authenticated, service_role;
revoke all on function private.consume_legacy_line(text, public.order_items) from public, anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 9. admin_set_tracking_mode() - no data can be lost by switching
-- ----------------------------------------------------------------------------
create or replace function public.admin_set_tracking_mode(
  p_product_id text,
  p_variant_id uuid,
  p_mode       text,
  p_note       text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note    text := btrim(coalesce(p_note, ''));
  v_product public.products;
  v_variant public.product_variants;
  v_current text;
  v_number  integer;
  v_live    integer;
  v_lots    integer;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_mode is null or p_mode not in ('quantity', 'unit') then
    raise exception 'invalid_mode: choose quantity or unit tracking' using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  select * into v_product from public.products where id = p_product_id for update;
  if not found then
    raise exception 'unknown_product: %', coalesce(p_product_id, '(missing)') using errcode = 'P0001';
  end if;

  if p_variant_id is not null then
    select * into v_variant from public.product_variants
     where id = p_variant_id and product_id = p_product_id for update;
    if not found then
      raise exception 'variant_product_mismatch: that variant does not belong to %', p_product_id using errcode = 'P0001';
    end if;
    if v_variant.stock is null then
      raise exception 'variant_inherits_product_stock: this variant shares its product''s stock; set the mode on the product'
        using errcode = 'P0001';
    end if;
    v_current := coalesce(v_variant.tracking_mode, v_product.tracking_mode);
    v_number := v_variant.stock;
    select count(*)::integer into v_live from public.inventory_units u
     where u.variant_id = p_variant_id and u.status in ('in_stock', 'reserved', 'quarantined');
  else
    v_current := v_product.tracking_mode;
    v_number := v_product.stock;
    select count(*)::integer into v_live from public.inventory_units u
     where u.product_id = p_product_id and u.status in ('in_stock', 'reserved', 'quarantined')
       and (u.variant_id is null or exists (
             select 1 from public.product_variants pv where pv.id = u.variant_id and pv.stock is null));
  end if;

  if v_current = p_mode then
    return jsonb_build_object('product_id', p_product_id, 'variant_id', p_variant_id, 'tracking_mode', p_mode, 'changed', false);
  end if;

  if v_number <> 0 then
    raise exception 'tracking_mode_locked: % is still in stock. Count it, set the stock to 0 with Adjust stock, then switch and receive the items.', v_number
      using errcode = 'P0001';
  end if;
  if v_live > 0 then
    raise exception 'tracking_mode_locked: % individually tracked units are still in the shop or quarantine', v_live
      using errcode = 'P0001';
  end if;
  if private.reserved_quantity(p_product_id, p_variant_id) > 0
     or exists (select 1 from public.stock_reservations r
                 where r.product_id = p_product_id and r.holder_variant_id is not distinct from p_variant_id
                   and r.status = 'active') then
    raise exception 'tracking_mode_locked: online orders still hold this stock' using errcode = 'P0001';
  end if;

  select coalesce(sum(l.open_quantity), 0)::integer into v_lots from public.quarantine_lots l
   where l.product_id = p_product_id and l.variant_id is not distinct from p_variant_id;
  if v_lots > 0 then
    raise exception 'tracking_mode_locked: % returned items are waiting in quarantine', v_lots using errcode = 'P0001';
  end if;

  if p_variant_id is not null then
    update public.product_variants set tracking_mode = p_mode where id = p_variant_id;
  else
    update public.products set tracking_mode = p_mode where id = p_product_id;
  end if;

  perform private.audit('tracking_mode', p_product_id || coalesce(':' || p_variant_id::text, ''), 'change',
                        jsonb_build_object('tracking_mode', v_current),
                        jsonb_build_object('tracking_mode', p_mode), v_note);

  return jsonb_build_object('product_id', p_product_id, 'variant_id', p_variant_id, 'tracking_mode', p_mode, 'changed', true);
end;
$$;

revoke all on function public.admin_set_tracking_mode(text, uuid, text, text) from public, anon, service_role;
grant execute on function public.admin_set_tracking_mode(text, uuid, text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 10. Order status changes
-- ----------------------------------------------------------------------------
-- Driven by stock_state, not by comparing statuses, so moving an order back and
-- forth can never deduct twice: 'consumed' has nothing left to do.
create or replace function private.apply_order_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_is_shipped boolean := new.status in ('shipped', 'delivered');
  v_was_active boolean := old.status not in ('cancelled', 'refunded');
  v_is_active  boolean := new.status not in ('cancelled', 'refunded');
  v_state      text := new.stock_state;
  v_products   text[];
  v_item       public.order_items;
  v_expires    timestamptz;
  v_close      text;
  v_flagged    integer := 0;
begin
  select array_agg(i.product_id) into v_products
    from public.order_items i where i.order_id = new.id and i.product_id is not null;
  perform private.lock_products(coalesce(v_products, '{}'::text[]));

  -- Brought back after a cancellation: hold stock again, or refuse.
  if v_is_active and not v_was_active then
    if v_state in ('released', 'expired') then
      v_expires := case when new.status = 'pending' then now() + private.reservation_window() end;
      for v_item in
        select * from public.order_items where order_id = new.id order by product_id, variant_id, id
      loop
        if v_item.product_id is null then
          raise exception 'product_unavailable: a product on order % no longer exists', new.order_number
            using errcode = 'P0001';
        end if;
        perform private.reserve_order_line(new.id, v_item.id, v_item.product_id, v_item.variant_id,
                                           v_item.quantity, v_expires);
      end loop;
      v_state := 'reserved';
    elsif v_state = 'legacy_closed' then
      v_state := 'legacy_open';
    end if;
  end if;

  -- Cancelled or refunded.
  if v_was_active and not v_is_active then
    if v_state = 'reserved' then
      v_close := case when old.status = 'pending' and new.reservation_expires_at <= now()
                      then 'expired' else 'released' end;
      for v_item in
        select * from public.order_items where order_id = new.id order by product_id, variant_id, id
      loop
        perform private.release_order_line(v_item.id, v_close,
                                           'Released: order ' || new.order_number || ' ' || new.status);
      end loop;
      v_state := v_close;
    elsif v_state = 'legacy_open' then
      v_state := 'legacy_closed';
    elsif v_state in ('consumed', 'legacy_done', 'needs_reconciliation') then
      insert into public.order_events (order_id, from_status, to_status, actor_id, note)
      values (new.id, old.status, new.status, (select auth.uid()),
              'Stock was not restored: this order had already shipped. Record a customer return when the goods actually come back.');
    end if;
  end if;

  -- First shipment: reservation becomes a sale, exactly once.
  if v_is_shipped then
    if v_state = 'reserved' then
      for v_item in
        select * from public.order_items where order_id = new.id order by product_id, variant_id, id
      loop
        perform private.consume_order_line(new.order_number, v_item);
      end loop;
      v_state := 'consumed';
    elsif v_state = 'legacy_open' then
      for v_item in
        select * from public.order_items where order_id = new.id order by product_id, variant_id, id
      loop
        if not private.consume_legacy_line(new.order_number, v_item) then
          v_flagged := v_flagged + v_item.quantity;
        end if;
      end loop;
      v_state := case when v_flagged > 0 then 'needs_reconciliation' else 'consumed' end;
      if v_flagged > 0 then
        insert into public.order_events (order_id, from_status, to_status, actor_id, note)
        values (new.id, new.status, new.status, (select auth.uid()),
                v_flagged || ' item(s) on this pre-rollout order could not be deducted from stock. See the reconciliation list in Inventory.');
      end if;
    end if;
  end if;

  -- Only a pending order counts down. Confirmed and processing never expire.
  v_expires := case
    when v_state = 'reserved' and new.status = 'pending' then
      case when old.status = 'pending' then new.reservation_expires_at else now() + private.reservation_window() end
  end;

  if v_state = 'reserved' then
    update public.stock_reservations set expires_at = v_expires
     where order_id = new.id and status = 'active';
  end if;

  update public.orders
     set stock_state = v_state, reservation_expires_at = v_expires
   where id = new.id;

  return null;
end;
$$;

-- The trigger itself (orders_apply_stock) was created by 20261028120000 and calls
-- this function by name, so replacing the function is enough.


-- ----------------------------------------------------------------------------
-- 11. place_order: reservation only, with request-id idempotency
-- ----------------------------------------------------------------------------
-- Pricing, warranty, condition and anti-tampering are unchanged from
-- 20261028120000. What changed: products are locked before any child row exists,
-- limits are enforced, and the line reserves stock instead of taking it.
create or replace function private.place_order_impl(
  p_lines      jsonb,
  p_notes      text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_tier        text;
  v_settings    public.store_settings;
  v_policy      public.inventory_policy;
  v_fingerprint text;
  v_existing    public.orders;
  v_product_ids text[];
  v_requested   bigint;
  v_held        bigint;
  v_active      bigint;
  v_order_id    uuid;
  v_number      text;
  v_expires     timestamptz;
  v_subtotal    bigint := 0;
  v_line        jsonb;
  v_qty         integer;
  v_product     public.products;
  v_variant     public.product_variants;
  v_variant_key text;
  v_option_id   uuid;
  v_option      public.product_warranty_options;
  v_plan        public.product_warranty_plans;
  v_wtype       text;
  v_cond        public.product_conditions;
  v_condition   text;
  v_price       record;
  v_base        bigint;
  v_warranty    bigint;
  v_grade       text;
  v_image       text;
  v_label       text;
  v_item_id     uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to place an order' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 50 then
    raise exception 'invalid_lines: between 1 and 50 order lines are required' using errcode = '22023';
  end if;

  if p_notes is not null and length(p_notes) > 500 then
    raise exception 'invalid_notes: notes are limited to 500 characters' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object('lines', p_lines, 'notes', nullif(btrim(p_notes), '')));

  -- Replay: a retry after a lost response returns the first order.
  select * into v_existing from public.orders where profile_id = v_uid and request_id = p_request_id;
  if found then
    if v_existing.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different order' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_existing.id, 'order_number', v_existing.order_number,
                              'total_cents', v_existing.total_cents, 'replayed', true);
  end if;

  v_tier := private.current_customer_type();

  select * into v_settings from public.store_settings where id;
  if found then
    if v_settings.maintenance_mode then
      raise exception 'store_unavailable: the store is in maintenance mode' using errcode = 'P0001';
    end if;
    if v_tier = 'retail' and not v_settings.retail_enabled then
      raise exception 'store_unavailable: the retail store is unavailable' using errcode = 'P0001';
    end if;
    if v_tier = 'wholesale_vip' and not v_settings.wholesale_enabled then
      raise exception 'store_unavailable: the wholesale store is unavailable' using errcode = 'P0001';
    end if;
  end if;

  -- First pass: shape only, so nothing is locked for a malformed request.
  for v_line in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'invalid_lines: each line must be an object' using errcode = '22023';
    end if;
    if coalesce(jsonb_typeof(v_line -> 'quantity'), '') <> 'number'
       or coalesce(v_line ->> 'quantity', '') !~ '^[0-9]{1,2}$'
       or (v_line ->> 'quantity')::integer < 1 then
      raise exception 'invalid_quantity: quantity must be a whole number from 1 to 99' using errcode = '22023';
    end if;
  end loop;

  -- One order at a time per customer, so a limit cannot be beaten by racing.
  perform 1 from public.profiles where id = v_uid for no key update;

  select * into v_policy from public.inventory_policy where id;
  if v_policy.max_reserved_units_per_customer is not null or v_policy.max_active_orders_per_customer is not null then
    select coalesce(sum(r.quantity), 0), count(distinct r.order_id)
      into v_held, v_active
      from public.stock_reservations r
      join public.orders o on o.id = r.order_id
     where o.profile_id = v_uid and r.status = 'active' and (r.expires_at is null or r.expires_at > now());

    select coalesce(sum((value ->> 'quantity')::integer), 0) into v_requested from jsonb_array_elements(p_lines);

    if v_policy.max_reserved_units_per_customer is not null
       and v_held + v_requested > v_policy.max_reserved_units_per_customer then
      raise exception 'reservation_limit_reached: this account may hold % items at a time (holding %, requested %)',
        v_policy.max_reserved_units_per_customer, v_held, v_requested using errcode = 'P0001';
    end if;
    if v_policy.max_active_orders_per_customer is not null
       and v_active + 1 > v_policy.max_active_orders_per_customer then
      raise exception 'reservation_limit_reached: this account may have % open orders at a time',
        v_policy.max_active_orders_per_customer using errcode = 'P0001';
    end if;
  end if;

  -- Parents first: products sorted and locked before any order line references
  -- them. Overdue holds on these products are released on the way.
  select array_agg(value ->> 'product_id') into v_product_ids from jsonb_array_elements(p_lines);
  perform private.sweep_and_lock(v_product_ids);

  v_number := 'AE-' || to_char(now() at time zone 'Asia/Colombo', 'YYMMDD') || '-'
              || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  v_expires := now() + private.reservation_window();

  begin
    insert into public.orders (order_number, profile_id, status, customer_type_at_purchase,
                               subtotal_cents, total_cents, currency, notes, stock_state,
                               reservation_expires_at, request_id, request_fingerprint)
    values (v_number, v_uid, 'pending', v_tier, 0, 0, 'LKR', nullif(btrim(p_notes), ''), 'reserved',
            v_expires, p_request_id, v_fingerprint)
    returning id into v_order_id;
  exception when unique_violation then
    -- A concurrent copy of this request got there first and has now committed.
    select * into v_existing from public.orders where profile_id = v_uid and request_id = p_request_id;
    if not found then
      raise;
    end if;
    if v_existing.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different order' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_existing.id, 'order_number', v_existing.order_number,
                              'total_cents', v_existing.total_cents, 'replayed', true);
  end;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_qty := (v_line ->> 'quantity')::integer;

    select * into v_product from public.products
     where id = v_line ->> 'product_id' and is_active;
    if not found then
      raise exception 'product_unavailable: %', coalesce(v_line ->> 'product_id', '(missing)') using errcode = 'P0001';
    end if;

    v_variant := null;
    v_variant_key := nullif(v_line ->> 'variant_key', '');
    if v_variant_key is not null then
      select * into v_variant from public.product_variants
       where product_id = v_product.id and legacy_key = v_variant_key;
      if not found then
        raise exception 'variant_unavailable: % / %', v_product.id, v_variant_key using errcode = 'P0001';
      end if;
    elsif exists (select 1 from public.product_variants where product_id = v_product.id) then
      raise exception 'variant_required: choose an option for %', v_product.id using errcode = 'P0001';
    end if;

    -- Base price, resolved here at the caller's tier (unchanged precedence).
    select * into v_price from private.resolve_price(v_product.id, v_variant.id, v_tier);
    if v_price is null then
      raise exception 'price_unavailable: % has no price yet', v_product.id using errcode = 'P0001';
    end if;
    v_base := v_price.price_cents;

    -- Condition of the item actually bought. A variant uses only its own row.
    v_cond := null;
    select * into v_cond from public.product_conditions
     where product_id = v_product.id and variant_id is not distinct from v_variant.id;
    v_condition := coalesce(v_cond.condition, 'brand_new');
    v_grade := null;
    if v_cond.condition_grade_id is not null then
      select g.label into v_grade from public.condition_grades g where g.id = v_cond.condition_grade_id;
    end if;

    -- Warranty plan: the variant's override, else the product default, else none.
    v_plan := null;
    if v_variant.id is not null then
      select * into v_plan from public.product_warranty_plans
       where product_id = v_product.id and variant_id = v_variant.id;
    end if;
    if v_plan.id is null then
      select * into v_plan from public.product_warranty_plans
       where product_id = v_product.id and variant_id is null;
    end if;
    v_wtype := coalesce(v_plan.warranty_type, 'none');

    v_option := null;
    v_warranty := 0;
    v_label := null;
    v_option_id := null;
    if v_line ? 'warranty_option_id' and jsonb_typeof(v_line -> 'warranty_option_id') = 'string' then
      begin
        v_option_id := (v_line ->> 'warranty_option_id')::uuid;
      exception when invalid_text_representation then
        raise exception 'warranty_option_invalid: malformed id' using errcode = '22023';
      end;
    end if;

    if v_wtype = 'optional_paid' then
      if v_option_id is null then
        select * into v_option from public.product_warranty_options
         where plan_id = v_plan.id and is_default and is_enabled;
      else
        select * into v_option from public.product_warranty_options
         where id = v_option_id and plan_id = v_plan.id and is_enabled;
      end if;
      if v_option.id is null then
        raise exception 'warranty_option_invalid: choose an available warranty for %', v_product.id
          using errcode = 'P0001';
      end if;
      v_warranty := v_option.additional_price_cents;
      v_label := v_option.duration_months || case when v_option.duration_months = 1 then ' Month' else ' Months' end
                 || case v_product.subcategory
                      when 'Displays'  then ' Part Warranty'
                      when 'Batteries' then ' Battery Warranty'
                      else ' Warranty' end;
    elsif v_option_id is not null then
      raise exception 'warranty_not_applicable: % has no selectable warranty', v_product.id using errcode = 'P0001';
    elsif v_wtype = 'included' then
      v_label := coalesce(nullif(btrim(v_plan.warranty_duration), '') || ' Warranty (included)', 'Included warranty');
    end if;

    select i.path into v_image from public.product_images i
     where i.product_id = v_product.id
       and (i.variant_id is null or i.variant_id is not distinct from v_variant.id)
     order by (i.variant_id is not null) desc, i.is_primary desc, i.position asc limit 1;

    insert into public.order_items (
      order_id, product_id, variant_id, product_name_snapshot, variant_label_snapshot,
      image_path_snapshot, unit_price_cents, quantity, line_total_cents, tier_code_snapshot,
      price_id, base_unit_price_cents, condition_snapshot, condition_grade_snapshot,
      warranty_option_id, warranty_months_snapshot, warranty_label_snapshot,
      warranty_price_cents_snapshot
    ) values (
      v_order_id, v_product.id, v_variant.id, v_product.name, v_variant.name,
      v_image, v_base + v_warranty, v_qty, (v_base + v_warranty) * v_qty, v_price.tier_code,
      v_price.price_id, v_base, v_condition, v_grade,
      v_option.id,
      case v_wtype
        when 'optional_paid' then v_option.duration_months
        when 'included' then v_plan.warranty_months
      end,
      v_label,
      v_warranty
    )
    returning id into v_item_id;

    -- Hold the stock. Refused if this exact product + variant has run out.
    perform private.reserve_order_line(v_order_id, v_item_id, v_product.id, v_variant.id, v_qty, v_expires);

    v_subtotal := v_subtotal + (v_base + v_warranty) * v_qty;
  end loop;

  update public.orders
     set subtotal_cents = v_subtotal, total_cents = v_subtotal
   where id = v_order_id;

  insert into public.order_events (order_id, from_status, to_status, actor_id, note)
  values (v_order_id, null, 'pending', v_uid, 'Order placed by customer');

  return jsonb_build_object('id', v_order_id, 'order_number', v_number, 'total_cents', v_subtotal, 'replayed', false);
end;
$$;

revoke all on function private.place_order_impl(jsonb, text, uuid) from public, anon, authenticated, service_role;

-- New clients: a retry after a lost response returns the first order. A distinct
-- name rather than an overload, because PostgREST cannot pick between overloads
-- when place_order's defaulted p_notes is omitted.
create or replace function public.place_order_v2(
  p_lines      jsonb,
  p_notes      text,
  p_request_id uuid
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.place_order_impl(p_lines, p_notes, p_request_id)
$$;

comment on function public.place_order_v2(jsonb, text, uuid) is
  'Customer order placement with request-id idempotency. Reserves stock for 48 hours; the client never supplies an amount.';

revoke all on function public.place_order_v2(jsonb, text, uuid) from public, anon, service_role;
grant execute on function public.place_order_v2(jsonb, text, uuid) to authenticated;

-- Installed APKs call this. Same signature and result keys; each call is its own
-- request, so these clients keep their old retry behaviour until they update.
create or replace function public.place_order(
  p_lines jsonb,
  p_notes text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.place_order_impl(p_lines, p_notes, gen_random_uuid())
$$;

comment on function public.place_order(jsonb, text) is
  'Compatibility entry point for installed apps. See place_order_v2. Reserves stock for 48 hours; the client never supplies an amount.';


-- ----------------------------------------------------------------------------
-- 12. Expiry entry point
-- ----------------------------------------------------------------------------
-- Staff (the admin panel runs it on load), the service role (external scheduler,
-- see supabase/functions/expire-reservations) and operator sessions.
create or replace function public.expire_pending_orders(p_limit integer default 200)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '');
begin
  if not (v_role = 'service_role'
          or private.has_role('staff')
          or (v_role = '' and pg_catalog.pg_has_role(session_user, 'postgres', 'MEMBER'))) then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'invalid_limit: choose 1 to 1000' using errcode = '22023';
  end if;
  return jsonb_build_object('expired', private.sweep_and_lock(null, p_limit));
end;
$$;

comment on function public.expire_pending_orders(integer) is
  'Cancels unconfirmed pending orders older than 48 hours and releases their stock. Safe to run repeatedly: a released order no longer matches.';

revoke all on function public.expire_pending_orders(integer) from public, anon;
grant execute on function public.expire_pending_orders(integer) to authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 13. admin_set_stock(): tracked per holder, never below what is reserved
-- ----------------------------------------------------------------------------
-- Same signature, grants and P1 contract. Changes from 20261028120000: the
-- tracked check looks at this stock holder, so an own-stock variant next to a
-- tracked sibling stays adjustable; and stock cannot go below active holds.
create or replace function public.admin_set_stock(
  p_product_id        text,
  p_variant_id        uuid,
  p_expected_quantity integer,
  p_new_quantity      integer,
  p_reason            text,
  p_note              text,
  p_request_id        uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid        uuid := (select auth.uid());
  v_note       text := btrim(coalesce(p_note, ''));
  v_product    public.products;
  v_variant    public.product_variants;
  v_prev       public.inventory_movements;
  v_move       public.inventory_movements;
  v_before     integer;
  v_current    integer;
  v_delta      integer;
  v_reserved   integer;
  v_constraint text;
begin
  -- 1. Authorisation, before anything is read.
  if v_uid is null then
    raise exception 'not_authenticated: sign in to adjust stock' using errcode = '42501';
  end if;
  if not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;

  -- 2. Input that needs no database read.
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;
  if p_new_quantity is null or p_new_quantity < 0 or p_new_quantity > 100000 then
    raise exception 'invalid_quantity: stock must be a whole number from 0 to 100000' using errcode = '22023';
  end if;
  if p_expected_quantity is null or p_expected_quantity < 0 or p_expected_quantity > 100000 then
    raise exception 'invalid_quantity: the expected stock must be a whole number from 0 to 100000' using errcode = '22023';
  end if;
  if p_reason is null or p_reason not in
     ('restock', 'adjustment', 'damage', 'return', 'stock_count', 'correction', 'opening_balance') then
    raise exception 'invalid_reason: %', coalesce(p_reason, '(missing)') using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  -- 3. Lock product first, then variant: one lock order everywhere.
  select * into v_product from public.products where id = p_product_id for update;
  if not found then
    raise exception 'unknown_product: %', coalesce(p_product_id, '(missing)') using errcode = 'P0001';
  end if;

  if p_variant_id is not null then
    select * into v_variant from public.product_variants
     where id = p_variant_id and product_id = p_product_id
     for update;
    if not found then
      raise exception 'variant_product_mismatch: that variant does not belong to %', p_product_id using errcode = 'P0001';
    end if;
  end if;

  v_current := case when p_variant_id is null then v_product.stock else v_variant.stock end;

  -- 4. Replay. Read after the locks, so a concurrent identical request sees
  --    the committed row of the one that went first.
  select * into v_prev from public.inventory_movements where request_id = p_request_id;
  if found then
    if v_prev.actor_id is not distinct from v_uid
       and v_prev.product_id = p_product_id
       and v_prev.variant_id is not distinct from p_variant_id
       and v_prev.quantity_before = p_expected_quantity
       and v_prev.quantity_after = p_new_quantity
       and v_prev.reason = p_reason
       and v_prev.note is not distinct from v_note then
      return jsonb_build_object(
        'movement_id', v_prev.id, 'product_id', v_prev.product_id, 'variant_id', v_prev.variant_id,
        'quantity_before', v_prev.quantity_before, 'quantity_after', v_prev.quantity_after,
        'delta', v_prev.delta, 'reason', v_prev.reason, 'created_at', v_prev.created_at,
        'current_quantity', v_current, 'replayed', true);
    end if;
    raise exception 'request_id_reused: this request id was already used for a different adjustment'
      using errcode = 'P0001';
  end if;

  -- 5. State checks.
  if p_variant_id is not null and v_variant.stock is null then
    raise exception 'variant_inherits_product_stock: this variant shares its product''s stock; adjust the product'
      using errcode = 'P0001';
  end if;

  -- An individually tracked holder moves only with its units.
  if private.tracking_mode_of(p_product_id, p_variant_id) = 'unit' then
    raise exception 'unit_tracked: % is tracked by barcode; receive stock with a GRN, sell or write off units instead', p_product_id
      using errcode = 'P0001',
            hint = 'Goods Received to add units; Inventory -> Units to write one off.';
  end if;

  v_before := v_current;
  if v_before <> p_expected_quantity then
    raise exception 'stale_quantity: stock is now %, not %', v_before, p_expected_quantity using errcode = 'P0001';
  end if;

  v_delta := p_new_quantity - v_before;
  if v_delta = 0 then
    raise exception 'no_change: stock is already %', v_before using errcode = 'P0001';
  end if;

  if p_reason in ('restock', 'return') and v_delta < 0 then
    raise exception 'invalid_reason: % can only increase stock', p_reason using errcode = '22023';
  end if;
  if p_reason = 'damage' and v_delta > 0 then
    raise exception 'invalid_reason: damage can only decrease stock' using errcode = '22023';
  end if;
  if p_reason = 'opening_balance' and (
       v_before <> 0
       or exists (select 1 from public.inventory_movements m
                  where m.product_id = p_product_id and m.variant_id is not distinct from p_variant_id)) then
    raise exception 'invalid_reason: opening_balance is only for an item at zero with no stock history'
      using errcode = '22023';
  end if;

  v_reserved := private.reserved_quantity(p_product_id, p_variant_id);
  if p_new_quantity < v_reserved then
    raise exception 'stock_reserved: % are held for online orders, so stock cannot go below that. Cancel those orders first.', v_reserved
      using errcode = 'P0001';
  end if;

  -- 6. Ledger row first: it is what authorises the stock write in the guard.
  begin
    insert into public.inventory_movements
      (product_id, variant_id, delta, reason, actor_id, note, quantity_before, quantity_after, request_id)
    values
      (p_product_id, p_variant_id, v_delta, p_reason, v_uid, v_note, v_before, p_new_quantity, p_request_id)
    returning * into v_move;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'inventory_movements_request_id_key' then
      -- Taken by a concurrent request for another item.
      raise exception 'request_id_reused: this request id was already used for a different adjustment'
        using errcode = 'P0001';
    end if;
    raise;
  end;

  -- 7. The stock write. The guard verifies the row above.
  if p_variant_id is null then
    update public.products set stock = p_new_quantity where id = p_product_id;
  else
    update public.product_variants set stock = p_new_quantity where id = p_variant_id;
  end if;

  return jsonb_build_object(
    'movement_id', v_move.id, 'product_id', v_move.product_id, 'variant_id', v_move.variant_id,
    'quantity_before', v_move.quantity_before, 'quantity_after', v_move.quantity_after,
    'delta', v_move.delta, 'reason', v_move.reason, 'created_at', v_move.created_at,
    'current_quantity', p_new_quantity, 'replayed', false);
end;
$$;


-- ----------------------------------------------------------------------------
-- 14. What the storefront may show
-- ----------------------------------------------------------------------------
-- One row per active product (variant_id NULL: anything of this product can be
-- bought) and one per variant (that exact option). products.stock alone would be
-- wrong twice over: it ignores holds, and a shared pool hides an empty variant.
-- Readable by anyone who can read the catalog; exposes no barcode, IMEI or cost.
create or replace function public.catalog_availability()
returns table (
  product_id text,
  variant_id uuid,
  legacy_key text,
  available  integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.product_id, v.id, v.legacy_key, private.available_quantity(v.product_id, v.id)
    from public.product_variants v
    join public.products p on p.id = v.product_id
   where p.is_active
  union all
  select p.id, null::uuid, null::text,
         case
           when not exists (select 1 from public.product_variants x where x.product_id = p.id)
             then private.available_quantity(p.id, null)
           else (
             -- Own-stock and unit-tracked variants count separately; a shared
             -- quantity pool counts once, however many variants draw on it.
             select coalesce(sum(private.available_quantity(p.id, x.id))
                               filter (where x.stock is not null or p.tracking_mode = 'unit'), 0)::integer
                    + case when p.tracking_mode = 'quantity' and bool_or(x.stock is null)
                           then private.available_quantity(p.id, null) else 0 end
               from public.product_variants x where x.product_id = p.id
           )
         end
    from public.products p
   where p.is_active
$$;

revoke all on function public.catalog_availability() from public;
grant execute on function public.catalog_availability() to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 15. Self-verification
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['inventory_audit_log', 'inventory_locations', 'inventory_policy',
                           'stock_reservations', 'stock_reconciliation_flags'] loop
    if has_table_privilege('anon', 'public.' || t, 'SELECT')
       or has_table_privilege('authenticated', 'public.' || t, 'INSERT')
       or has_table_privilege('authenticated', 'public.' || t, 'UPDATE')
       or has_table_privilege('authenticated', 'public.' || t, 'DELETE')
       or has_table_privilege('service_role', 'public.' || t, 'INSERT')
       or has_table_privilege('service_role', 'public.' || t, 'UPDATE') then
      raise exception 'verify: a client role can write % (or anon can read it)', t;
    end if;
    if not (select relrowsecurity from pg_class where oid = ('public.' || t)::regclass) then
      raise exception 'verify: RLS is off on %', t;
    end if;
  end loop;

  if has_function_privilege('authenticated', 'private.move_stock(text, uuid, integer, text, text, uuid, uuid, uuid, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.place_order_impl(jsonb, text, uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.place_order_v2(jsonb, text, uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.place_order(jsonb, text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.place_order_v2(jsonb, text, uuid)', 'EXECUTE') then
    raise exception 'verify: function grants are wrong';
  end if;

  if has_table_privilege('authenticated', 'public.orders', 'INSERT')
     or has_table_privilege('authenticated', 'public.order_items', 'INSERT') then
    raise exception 'verify: orders can still be inserted directly';
  end if;

  raise notice 'verified: reservation tables read-only for clients; orders created only by place_order';
end
$$;


-- ----------------------------------------------------------------------------
-- Rollback: not practical once a reservation exists. Stock semantics change here
-- (on hand, not available), and reverting the code would make every active hold
-- invisible. Before go-live, restore from the pre-migration backup. After go-live,
-- fix forward.
-- ----------------------------------------------------------------------------
