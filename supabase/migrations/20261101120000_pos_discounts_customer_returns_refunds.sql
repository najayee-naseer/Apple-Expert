-- ============================================================================
-- Apple Expert · Inventory integration 3/4 · shop counter, returns and refunds
-- ----------------------------------------------------------------------------
-- COUNTER SALES
--   A bill line is either one scanned unit, or a quantity of a quantity-tracked
--   item. Prices are resolved here at the customer's tier: retail, or wholesale
--   when the cashier attaches an account whose VIP status is live.
--
-- DISCOUNTS (REQUIRES BUSINESS APPROVAL of the threshold)
--   Owner/admin: up to the bill. Staff: up to inventory_policy.staff_max_discount_bps,
--   which defaults to 0 as the safe setting. Above it, an owner/admin approves
--   that discount for that exact bill. An approval cannot be reused or moved.
--
-- RETURNS AND REFUNDS ARE SEPARATE FACTS
--   customer_returns:  goods came back. They ALWAYS go to quarantine; a person
--                      verifies them before they are sellable again.
--   customer_refunds:  money went back. Recording one never moves stock, and
--                      returning goods never implies one.
--   supplier returns are a different flow (migration 4/4).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Bills
-- ----------------------------------------------------------------------------
alter table public.pos_sales
  add column customer_profile_id  uuid references public.profiles (id) on delete set null,
  add column tier_code            text not null default 'retail' references public.price_tiers (code) on delete restrict,
  add column payment_reference    text check (payment_reference is null or length(payment_reference) <= 60),
  add column request_fingerprint  text,
  add column discount_approval_id uuid;

alter table public.pos_sale_items
  alter column unit_id drop not null,
  alter column barcode_snapshot drop not null,
  add column quantity            integer not null default 1 check (quantity between 1 and 1000),
  add column line_total_cents    bigint,
  add column tier_code_snapshot  text not null default 'retail',
  add column returned_quantity   integer not null default 0 check (returned_quantity >= 0);

update public.pos_sale_items
   set line_total_cents = unit_price_cents,
       returned_quantity = case when returned_at is not null then 1 else 0 end;

alter table public.pos_sale_items
  alter column line_total_cents set not null,
  add constraint pos_sale_items_unit_is_one check (unit_id is null or quantity = 1),
  add constraint pos_sale_items_unit_has_barcode check (unit_id is null or barcode_snapshot is not null),
  add constraint pos_sale_items_returned_within check (returned_quantity <= quantity),
  add constraint pos_sale_items_total_matches check (line_total_cents = unit_price_cents * quantity);

create table public.pos_discount_approvals (
  id                 uuid primary key default gen_random_uuid(),
  sale_request_id    uuid not null,
  items_fingerprint  text not null,
  requested_by       uuid not null references public.profiles (id) on delete restrict,
  requested_cents    bigint not null check (requested_cents > 0),
  subtotal_cents     bigint not null check (subtotal_cents > 0),
  reason             text not null check (length(reason) between 3 and 300),
  status             text not null default 'pending'
                     check (status in ('pending', 'approved', 'rejected', 'used')),
  decided_by         uuid references public.profiles (id) on delete set null,
  decided_at         timestamptz,
  decision_note      text check (decision_note is null or length(decision_note) <= 300),
  used_sale_id       uuid references public.pos_sales (id) on delete restrict,
  expires_at         timestamptz not null,
  created_at         timestamptz not null default now(),
  constraint pos_discount_approvals_used check ((status = 'used') = (used_sale_id is not null))
);

create unique index pos_discount_approvals_open_key on public.pos_discount_approvals (sale_request_id)
  where status in ('pending', 'approved');
create index pos_discount_approvals_pending_idx on public.pos_discount_approvals (created_at desc)
  where status = 'pending';

alter table public.pos_sales
  add constraint pos_sales_discount_approval_fk
  foreign key (discount_approval_id) references public.pos_discount_approvals (id) on delete restrict;

alter table public.pos_discount_approvals enable row level security;
create policy "pos_discount_approvals own or admin read" on public.pos_discount_approvals
  for select to authenticated
  using (requested_by = (select auth.uid()) or private.has_role('admin'));

revoke all on public.pos_discount_approvals from anon;
revoke insert, update, delete, truncate on public.pos_discount_approvals from authenticated, service_role;
grant select on public.pos_discount_approvals to authenticated;


-- ----------------------------------------------------------------------------
-- 2. Customer returns, refunds and quarantined quantity
-- ----------------------------------------------------------------------------
create sequence private.customer_return_number_seq;
create sequence private.customer_refund_number_seq;
revoke all on sequence private.customer_return_number_seq, private.customer_refund_number_seq from public;

create table public.customer_returns (
  id                  uuid primary key default gen_random_uuid(),
  return_number       text not null unique,
  source_type         text not null check (source_type in ('pos', 'online')),
  pos_sale_id         uuid references public.pos_sales (id) on delete restrict,
  order_id            uuid references public.orders (id) on delete restrict,
  note                text check (note is null or length(note) <= 500),
  created_by          uuid references public.profiles (id) on delete set null,
  request_id          uuid not null unique,
  request_fingerprint text not null,
  created_at          timestamptz not null default now(),
  constraint customer_returns_one_source check (
    (source_type = 'pos' and pos_sale_id is not null and order_id is null)
    or (source_type = 'online' and order_id is not null and pos_sale_id is null))
);

create index customer_returns_pos_idx on public.customer_returns (pos_sale_id) where pos_sale_id is not null;
create index customer_returns_order_idx on public.customer_returns (order_id) where order_id is not null;
create index customer_returns_created_idx on public.customer_returns (created_at desc);

create table public.quarantine_lots (
  id                 uuid primary key default gen_random_uuid(),
  product_id         text not null references public.products (id) on delete restrict,
  variant_id         uuid references public.product_variants (id) on delete restrict,
  quantity           integer not null check (quantity > 0),
  open_quantity      integer not null,
  released_quantity  integer not null default 0 check (released_quantity >= 0),
  written_off_quantity integer not null default 0 check (written_off_quantity >= 0),
  customer_return_id uuid references public.customer_returns (id) on delete restrict,
  note               text check (note is null or length(note) <= 500),
  created_at         timestamptz not null default now(),
  constraint quarantine_lots_add_up check (open_quantity >= 0 and open_quantity + released_quantity + written_off_quantity = quantity)
);

create index quarantine_lots_open_idx on public.quarantine_lots (product_id, variant_id) where open_quantity > 0;

comment on table public.quarantine_lots is
  'Returned quantity-tracked goods waiting for a decision. Not in the stock number and not sellable until released.';

create table public.customer_return_items (
  id                 uuid primary key default gen_random_uuid(),
  customer_return_id uuid not null references public.customer_returns (id) on delete restrict,
  pos_sale_item_id   uuid references public.pos_sale_items (id) on delete restrict,
  order_item_id      uuid references public.order_items (id) on delete restrict,
  unit_id            uuid references public.inventory_units (id) on delete restrict,
  quarantine_lot_id  uuid references public.quarantine_lots (id) on delete restrict,
  product_id         text references public.products (id) on delete set null,
  variant_id         uuid references public.product_variants (id) on delete set null,
  product_name_snapshot text not null,
  variant_label_snapshot text,
  quantity           integer not null check (quantity > 0),
  condition          text not null check (condition in ('resaleable', 'opened', 'damaged', 'unverified')),
  constraint customer_return_items_one_line check ((pos_sale_item_id is null) <> (order_item_id is null)),
  constraint customer_return_items_unit_is_one check (unit_id is null or quantity = 1)
);

create index customer_return_items_return_idx on public.customer_return_items (customer_return_id);

create table public.customer_refunds (
  id                  uuid primary key default gen_random_uuid(),
  refund_number       text not null unique,
  source_type         text not null check (source_type in ('pos', 'online')),
  pos_sale_id         uuid references public.pos_sales (id) on delete restrict,
  order_id            uuid references public.orders (id) on delete restrict,
  customer_return_id  uuid references public.customer_returns (id) on delete restrict,
  amount_cents        bigint not null check (amount_cents > 0),
  method              text not null check (method in ('cash', 'card', 'bank_transfer', 'other')),
  reference           text check (reference is null or length(reference) <= 60),
  note                text check (note is null or length(note) <= 500),
  created_by          uuid references public.profiles (id) on delete set null,
  request_id          uuid not null unique,
  request_fingerprint text not null,
  created_at          timestamptz not null default now(),
  constraint customer_refunds_one_source check (
    (source_type = 'pos' and pos_sale_id is not null and order_id is null)
    or (source_type = 'online' and order_id is not null and pos_sale_id is null))
);

create index customer_refunds_pos_idx on public.customer_refunds (pos_sale_id) where pos_sale_id is not null;
create index customer_refunds_order_idx on public.customer_refunds (order_id) where order_id is not null;
create index customer_refunds_created_idx on public.customer_refunds (created_at desc);

alter table public.customer_returns      enable row level security;
alter table public.customer_return_items enable row level security;
alter table public.customer_refunds      enable row level security;
alter table public.quarantine_lots       enable row level security;

create policy "customer_returns staff read"      on public.customer_returns      for select to authenticated using (private.has_role('staff'));
create policy "customer_return_items staff read" on public.customer_return_items for select to authenticated using (private.has_role('staff'));
create policy "customer_refunds staff read"      on public.customer_refunds      for select to authenticated using (private.has_role('staff'));
create policy "quarantine_lots staff read"       on public.quarantine_lots       for select to authenticated using (private.has_role('staff'));

revoke all on public.customer_returns, public.customer_return_items, public.customer_refunds, public.quarantine_lots from anon;
revoke insert, update, delete, truncate
  on public.customer_returns, public.customer_return_items, public.customer_refunds, public.quarantine_lots
  from authenticated, service_role;
grant select on public.customer_returns, public.customer_return_items, public.customer_refunds, public.quarantine_lots
  to authenticated;


-- ----------------------------------------------------------------------------
-- 3. Counter lookups
-- ----------------------------------------------------------------------------
-- A customer's tier for the counter: mirrors private.current_customer_type(),
-- but for the account being served rather than the signed-in cashier.
create or replace function private.tier_of_profile(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.customer_type from public.profiles p
      where p.id = p_profile_id and (p.vip_expires_at is null or p.vip_expires_at > now())),
    'retail')
$$;

revoke all on function private.tier_of_profile(uuid) from public, anon, authenticated, service_role;

drop function if exists public.pos_lookup_unit(text);

-- Replaces pos_lookup_unit. A unit scan, priced at the served customer's tier.
create or replace function public.pos_lookup_unit(p_code text, p_customer_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code  text := private.normalize_serial(p_code);
  v_unit  public.inventory_units;
  v_name  text;
  v_vname text;
  v_price record;
begin
  if (select auth.uid()) is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if v_code is null or length(v_code) > 40 then
    raise exception 'unit_not_found: nothing was scanned' using errcode = 'P0001';
  end if;

  select * into v_unit from private.find_unit_by_code(v_code);
  if v_unit.id is null then
    raise exception 'unit_not_found: no item with barcode or IMEI %', v_code using errcode = 'P0001';
  end if;

  select p.name into v_name from public.products p where p.id = v_unit.product_id;
  select v.name into v_vname from public.product_variants v where v.id = v_unit.variant_id;
  select * into v_price from private.resolve_price(v_unit.product_id, v_unit.variant_id, private.tier_of_profile(p_customer_profile_id));

  return jsonb_build_object(
    'kind', 'unit',
    'unit_id', v_unit.id, 'barcode', v_unit.barcode, 'serial_number', v_unit.serial_number,
    'status', v_unit.status, 'product_id', v_unit.product_id, 'variant_id', v_unit.variant_id,
    'product_name', v_name, 'variant_name', v_vname,
    'price_cents', v_price.price_cents, 'tier_code', v_price.tier_code);
end;
$$;

revoke all on function public.pos_lookup_unit(text, uuid) from public, anon, service_role;
grant execute on function public.pos_lookup_unit(text, uuid) to authenticated;

-- A quantity-tracked item chosen from the product list.
create or replace function public.pos_quote_product(p_product_id text, p_variant_id uuid, p_customer_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name  text;
  v_vname text;
  v_price record;
begin
  if (select auth.uid()) is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  select p.name into v_name from public.products p where p.id = p_product_id;
  if v_name is null then
    raise exception 'unknown_product: %', coalesce(p_product_id, '(missing)') using errcode = 'P0001';
  end if;
  if p_variant_id is not null then
    select v.name into v_vname from public.product_variants v where v.id = p_variant_id and v.product_id = p_product_id;
    if v_vname is null then
      raise exception 'variant_product_mismatch: that variant does not belong to %', p_product_id using errcode = 'P0001';
    end if;
  elsif exists (select 1 from public.product_variants v where v.product_id = p_product_id) then
    raise exception 'variant_required: choose the variant' using errcode = 'P0001';
  end if;

  select * into v_price from private.resolve_price(p_product_id, p_variant_id, private.tier_of_profile(p_customer_profile_id));

  return jsonb_build_object(
    'kind', 'product', 'product_id', p_product_id, 'variant_id', p_variant_id,
    'product_name', v_name, 'variant_name', v_vname,
    'tracking_mode', private.tracking_mode_of(p_product_id, p_variant_id),
    'available', private.available_quantity(p_product_id, p_variant_id),
    'price_cents', v_price.price_cents, 'tier_code', v_price.tier_code);
end;
$$;

revoke all on function public.pos_quote_product(text, uuid, uuid) from public, anon, service_role;
grant execute on function public.pos_quote_product(text, uuid, uuid) to authenticated;

-- Finds the account by phone so its live wholesale status decides the price.
create or replace function public.pos_find_customer(p_phone text)
returns table (profile_id uuid, full_name text, phone text, tier_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if (select auth.uid()) is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if length(v_digits) < 9 then
    return;
  end if;
  return query
    select p.id, p.full_name, p.phone, private.tier_of_profile(p.id)
      from public.profiles p
     where right(regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g'), 9) = right(v_digits, 9)
     limit 5;
end;
$$;

revoke all on function public.pos_find_customer(text) from public, anon, service_role;
grant execute on function public.pos_find_customer(text) to authenticated;


-- ----------------------------------------------------------------------------
-- 4. Discount approval
-- ----------------------------------------------------------------------------
-- How long a discount request stays usable. A technical guard against a stale
-- approval being spent later, not a pricing policy.
create or replace function private.discount_approval_window()
returns interval
language sql
immutable
set search_path = ''
as $$ select interval '30 minutes' $$;

revoke all on function private.discount_approval_window() from public, anon, authenticated, service_role;

-- Bound to the sale's request id and its items. The subtotal is priced here so a
-- percentage shown to the approver is the real one.
create or replace function public.pos_request_discount_approval(
  p_sale_request_id     uuid,
  p_items               jsonb,
  p_customer_profile_id uuid,
  p_discount_cents      bigint,
  p_reason              text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_reason   text := btrim(coalesce(p_reason, ''));
  v_item     jsonb;
  v_tier     text := private.tier_of_profile(p_customer_profile_id);
  v_unit     public.inventory_units;
  v_price    record;
  v_subtotal bigint := 0;
  v_row      public.pos_discount_approvals;
begin
  if v_uid is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if p_sale_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;
  if length(v_reason) < 3 or length(v_reason) > 300 then
    raise exception 'invalid_note: give a reason of 3 to 300 characters' using errcode = '22023';
  end if;
  if p_discount_cents is null or p_discount_cents <= 0 then
    raise exception 'invalid_discount: enter the discount' using errcode = '22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'invalid_items: scan at least one item' using errcode = '22023';
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    if v_item ? 'code' then
      select * into v_unit from private.find_unit_by_code(private.normalize_serial(v_item ->> 'code'));
      if v_unit.id is null then
        raise exception 'unit_not_found: no item with barcode or IMEI %', v_item ->> 'code' using errcode = 'P0001';
      end if;
      select * into v_price from private.resolve_price(v_unit.product_id, v_unit.variant_id, v_tier);
      v_subtotal := v_subtotal + coalesce(v_price.price_cents, 0);
    else
      select * into v_price from private.resolve_price(v_item ->> 'product_id', nullif(v_item ->> 'variant_id', '')::uuid, v_tier);
      v_subtotal := v_subtotal + coalesce(v_price.price_cents, 0) * (v_item ->> 'quantity')::bigint;
    end if;
  end loop;

  if p_discount_cents > v_subtotal then
    raise exception 'invalid_discount: the discount is larger than the bill' using errcode = '22023';
  end if;

  -- A new request replaces this bill's previous unused one.
  update public.pos_discount_approvals
     set status = 'rejected', decision_note = 'Replaced by a newer request', decided_at = now()
   where sale_request_id = p_sale_request_id and requested_by = v_uid and status in ('pending', 'approved');

  insert into public.pos_discount_approvals
    (sale_request_id, items_fingerprint, requested_by, requested_cents, subtotal_cents, reason, expires_at)
  values
    (p_sale_request_id,
     private.fingerprint(jsonb_build_object('items', p_items, 'customer', p_customer_profile_id)),
     v_uid, p_discount_cents, v_subtotal, v_reason, now() + private.discount_approval_window())
  returning * into v_row;

  return jsonb_build_object('id', v_row.id, 'status', v_row.status, 'expires_at', v_row.expires_at);
end;
$$;

revoke all on function public.pos_request_discount_approval(uuid, jsonb, uuid, bigint, text) from public, anon, service_role;
grant execute on function public.pos_request_discount_approval(uuid, jsonb, uuid, bigint, text) to authenticated;

create or replace function public.admin_decide_discount_approval(
  p_approval_id uuid,
  p_approve     boolean,
  p_note        text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_row  public.pos_discount_approvals;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_approve is null then
    raise exception 'invalid_decision: approve or reject' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 300 then
    raise exception 'invalid_note: the note is limited to 300 characters' using errcode = '22023';
  end if;

  select * into v_row from public.pos_discount_approvals where id = p_approval_id for update;
  if not found then
    raise exception 'unknown_approval: %', coalesce(p_approval_id::text, '(missing)') using errcode = 'P0001';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'approval_decided: this request is already %', v_row.status using errcode = 'P0001';
  end if;
  if v_row.expires_at <= now() then
    raise exception 'approval_expired: this request has expired; the cashier must ask again' using errcode = 'P0001';
  end if;

  update public.pos_discount_approvals
     set status = case when p_approve then 'approved' else 'rejected' end,
         decided_by = v_uid, decided_at = now(), decision_note = v_note
   where id = v_row.id
  returning * into v_row;

  perform private.audit('pos_discount_approval', v_row.id::text, v_row.status, null,
                        jsonb_build_object('requested_cents', v_row.requested_cents, 'subtotal_cents', v_row.subtotal_cents,
                                           'requested_by', v_row.requested_by),
                        v_note);

  return jsonb_build_object('id', v_row.id, 'status', v_row.status);
end;
$$;

revoke all on function public.admin_decide_discount_approval(uuid, boolean, text) from public, anon, service_role;
grant execute on function public.admin_decide_discount_approval(uuid, boolean, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. pos_create_sale
-- ----------------------------------------------------------------------------
-- No APK has ever carried the previous signature, so it is replaced outright.
drop function if exists public.pos_create_sale(text[], text, bigint, text, text, text, uuid);

-- p_items: [{ "code": "AE00000001" | IMEI } | { "product_id", "variant_id", "quantity" }]
create or replace function public.pos_create_sale(
  p_items               jsonb,
  p_payment_method      text,
  p_payment_reference   text,
  p_discount_cents      bigint,
  p_customer_name       text,
  p_customer_phone      text,
  p_customer_profile_id uuid,
  p_note                text,
  p_discount_approval_id uuid,
  p_request_id          uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_name        text := nullif(btrim(coalesce(p_customer_name, '')), '');
  v_phone       text := nullif(btrim(coalesce(p_customer_phone, '')), '');
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_reference   text := nullif(btrim(coalesce(p_payment_reference, '')), '');
  v_discount    bigint := coalesce(p_discount_cents, 0);
  v_fingerprint text;
  v_items_fp    text;
  v_sale        public.pos_sales;
  v_item        jsonb;
  v_code        text;
  v_unit        public.inventory_units;
  v_unit_ids    uuid[] := '{}';
  v_product_ids text[] := '{}';
  v_qty_seen    text[] := '{}';
  v_product     public.products;
  v_variant     public.product_variants;
  v_variant_id  uuid;
  v_qty         integer;
  v_available   integer;
  v_tier        text;
  v_price       record;
  v_subtotal    bigint := 0;
  v_holder      record;
  v_policy      public.inventory_policy;
  v_approval    public.pos_discount_approvals;
  v_approval_id uuid := null;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to make a sale' using errcode = '42501';
  end if;
  if not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  v_items_fp := private.fingerprint(jsonb_build_object('items', p_items, 'customer', p_customer_profile_id));
  v_fingerprint := private.fingerprint(jsonb_build_object(
    'items', p_items, 'payment', p_payment_method, 'reference', v_reference, 'discount', v_discount,
    'name', v_name, 'phone', v_phone, 'customer', p_customer_profile_id, 'note', v_note));

  select * into v_sale from public.pos_sales where request_id = p_request_id;
  if found then
    if v_sale.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different bill' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_sale.id, 'bill_number', v_sale.bill_number,
                              'total_cents', v_sale.total_cents, 'replayed', true);
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 100 then
    raise exception 'invalid_items: add between 1 and 100 items' using errcode = '22023';
  end if;
  if p_payment_method is null or p_payment_method not in ('cash', 'card', 'bank_transfer', 'other') then
    raise exception 'invalid_payment: %', coalesce(p_payment_method, '(missing)') using errcode = '22023';
  end if;
  if v_reference is not null and length(v_reference) > 60 then
    raise exception 'invalid_payment: the payment reference is limited to 60 characters' using errcode = '22023';
  end if;
  if v_name is not null and length(v_name) > 120 then
    raise exception 'invalid_customer: the name is limited to 120 characters' using errcode = '22023';
  end if;
  if v_phone is not null and length(v_phone) > 30 then
    raise exception 'invalid_customer: the phone number is limited to 30 characters' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if v_discount < 0 then
    raise exception 'invalid_discount: the discount cannot be negative' using errcode = '22023';
  end if;

  v_tier := private.tier_of_profile(p_customer_profile_id);
  if p_customer_profile_id is not null
     and not exists (select 1 from public.profiles p where p.id = p_customer_profile_id) then
    raise exception 'invalid_customer: that customer account no longer exists' using errcode = 'P0001';
  end if;

  -- First pass: resolve and validate, no locks and no rows yet.
  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'invalid_items: each item must be an object' using errcode = '22023';
    end if;
    if v_item ? 'code' then
      v_code := private.normalize_serial(v_item ->> 'code');
      if v_code is null then
        raise exception 'invalid_items: an empty scan was sent' using errcode = '22023';
      end if;
      select * into v_unit from private.find_unit_by_code(v_code);
      if v_unit.id is null then
        raise exception 'unit_not_found: no item with barcode or IMEI %', v_code using errcode = 'P0001';
      end if;
      if v_unit.id = any (v_unit_ids) then
        raise exception 'duplicate_item: % was scanned twice', v_unit.barcode using errcode = '22023';
      end if;
      v_unit_ids := v_unit_ids || v_unit.id;
      v_product_ids := v_product_ids || v_unit.product_id;
    else
      if coalesce(jsonb_typeof(v_item -> 'quantity'), '') <> 'number'
         or coalesce(v_item ->> 'quantity', '') !~ '^[0-9]{1,4}$'
         or (v_item ->> 'quantity')::integer not between 1 and 1000 then
        raise exception 'invalid_quantity: a quantity must be a whole number from 1 to 1000' using errcode = '22023';
      end if;
      if (v_item ->> 'product_id') is null then
        raise exception 'invalid_items: an item has no product' using errcode = '22023';
      end if;
      v_code := (v_item ->> 'product_id') || '|' || coalesce(v_item ->> 'variant_id', '');
      if v_code = any (v_qty_seen) then
        raise exception 'duplicate_item: the same product appears twice; change its quantity instead' using errcode = '22023';
      end if;
      v_qty_seen := v_qty_seen || v_code;
      v_product_ids := v_product_ids || (v_item ->> 'product_id');
    end if;
  end loop;

  -- Parents first; overdue online holds on these products are released on the way.
  perform private.sweep_and_lock(v_product_ids);

  insert into public.pos_sales (bill_number, customer_name, customer_phone, customer_profile_id, tier_code,
                                payment_method, payment_reference, subtotal_cents, discount_cents, total_cents,
                                note, cashier_id, request_id, request_fingerprint)
  values ('POS-' || to_char(now() at time zone 'Asia/Colombo', 'YYMMDD') || '-'
            || lpad(nextval('private.pos_bill_number_seq')::text, 5, '0'),
          v_name, v_phone, p_customer_profile_id, v_tier, p_payment_method, v_reference, 0, 0, 0,
          v_note, v_uid, p_request_id, v_fingerprint)
  returning * into v_sale;

  -- Scanned units: each re-read under its lock first, so a reserved or sold unit
  -- reports itself rather than as a shortage.
  for v_unit in
    select * from public.inventory_units where id = any (v_unit_ids) order by barcode for update
  loop
    if v_unit.status <> 'in_stock' then
      raise exception 'unit_not_available: % is %', v_unit.barcode,
        case v_unit.status when 'reserved' then 'reserved for an online order'
                           when 'sold' then 'already sold'
                           when 'quarantined' then 'in quarantine'
                           when 'returned_to_supplier' then 'returned to the supplier'
                           else 'written off' end
        using errcode = 'P0001';
    end if;

    select * into v_product from public.products where id = v_unit.product_id;
    v_variant := null;
    if v_unit.variant_id is not null then
      select * into v_variant from public.product_variants where id = v_unit.variant_id;
    end if;

    select * into v_price from private.resolve_price(v_unit.product_id, v_unit.variant_id, v_tier);
    if v_price is null then
      raise exception 'price_unavailable: % has no retail price yet', v_product.name using errcode = 'P0001';
    end if;

    update public.inventory_units
       set status = 'sold', pos_sale_id = v_sale.id, status_changed_at = now(), status_note = null
     where id = v_unit.id;

    insert into public.pos_sale_items (pos_sale_id, unit_id, product_id, variant_id, product_name_snapshot,
                                       variant_label_snapshot, barcode_snapshot, serial_snapshot,
                                       unit_price_cents, quantity, line_total_cents, tier_code_snapshot, price_id)
    values (v_sale.id, v_unit.id, v_unit.product_id, v_unit.variant_id, v_product.name,
            v_variant.name, v_unit.barcode, v_unit.serial_number, v_price.price_cents, 1, v_price.price_cents,
            v_price.tier_code, v_price.price_id);

    v_subtotal := v_subtotal + v_price.price_cents;
  end loop;

  -- Then the number, by stock holder.
  for v_holder in
    select u.product_id, u.variant_id, count(*)::integer as qty
      from public.inventory_units u
     where u.id = any (v_unit_ids)
     group by u.product_id, u.variant_id
     order by u.product_id, u.variant_id
  loop
    perform private.move_stock(v_holder.product_id, v_holder.variant_id, -v_holder.qty, 'sale',
                               'Counter bill ' || v_sale.bill_number, null, null, v_sale.id);
  end loop;

  -- Quantity lines.
  for v_item in
    select value from jsonb_array_elements(p_items) where not (value ? 'code')
    order by value ->> 'product_id', value ->> 'variant_id'
  loop
    begin
      v_variant_id := nullif(v_item ->> 'variant_id', '')::uuid;
    exception when invalid_text_representation then
      raise exception 'invalid_variant: malformed variant id' using errcode = '22023';
    end;
    v_qty := (v_item ->> 'quantity')::integer;

    select * into v_product from public.products where id = v_item ->> 'product_id';
    if not found then
      raise exception 'unknown_product: %', v_item ->> 'product_id' using errcode = 'P0001';
    end if;
    v_variant := null;
    if v_variant_id is not null then
      select * into v_variant from public.product_variants where id = v_variant_id and product_id = v_product.id;
      if not found then
        raise exception 'variant_product_mismatch: that variant does not belong to %', v_product.id using errcode = 'P0001';
      end if;
    elsif exists (select 1 from public.product_variants where product_id = v_product.id) then
      raise exception 'variant_required: choose the variant for %', v_product.name using errcode = 'P0001';
    end if;
    if private.tracking_mode_of(v_product.id, v_variant_id) = 'unit' then
      raise exception 'scan_required: % is tracked individually. Scan its barcode or IMEI.', v_product.name using errcode = 'P0001';
    end if;

    v_available := private.available_quantity(v_product.id, v_variant_id);
    if v_qty > v_available then
      raise exception 'insufficient_stock: % (requested %, available %)', v_product.name, v_qty, v_available using errcode = 'P0001';
    end if;

    select * into v_price from private.resolve_price(v_product.id, v_variant_id, v_tier);
    if v_price is null then
      raise exception 'price_unavailable: % has no retail price yet', v_product.name using errcode = 'P0001';
    end if;

    perform private.move_stock(v_product.id, v_variant_id, -v_qty, 'sale',
                               'Counter bill ' || v_sale.bill_number, null, null, v_sale.id);

    insert into public.pos_sale_items (pos_sale_id, product_id, variant_id, product_name_snapshot, variant_label_snapshot,
                                       unit_price_cents, quantity, line_total_cents, tier_code_snapshot, price_id)
    values (v_sale.id, v_product.id, v_variant_id, v_product.name, v_variant.name, v_price.price_cents, v_qty,
            v_price.price_cents * v_qty, v_price.tier_code, v_price.price_id);

    v_subtotal := v_subtotal + v_price.price_cents * v_qty;
  end loop;

  -- Discount: enforced here against the subtotal just computed, not the screen's.
  if v_discount > v_subtotal then
    raise exception 'invalid_discount: the discount is larger than the bill' using errcode = '22023';
  end if;

  if v_discount > 0 and not private.has_role('admin') then
    select * into v_policy from public.inventory_policy where id;
    if v_discount * 10000 > v_subtotal * v_policy.staff_max_discount_bps then
      select * into v_approval from public.pos_discount_approvals
       where id = p_discount_approval_id for update;
      if not found
         or v_approval.status <> 'approved'
         or v_approval.requested_by <> v_uid
         or v_approval.sale_request_id <> p_request_id
         or v_approval.items_fingerprint <> v_items_fp
         or v_approval.requested_cents < v_discount
         or v_approval.expires_at <= now() then
        raise exception 'discount_approval_required: this discount needs an owner or admin to approve it for this bill'
          using errcode = 'P0001';
      end if;
      update public.pos_discount_approvals
         set status = 'used', used_sale_id = v_sale.id
       where id = v_approval.id;
      v_approval_id := v_approval.id;
    end if;
  end if;

  update public.pos_sales
     set subtotal_cents = v_subtotal, discount_cents = v_discount, total_cents = v_subtotal - v_discount,
         discount_approval_id = v_approval_id
   where id = v_sale.id;

  return jsonb_build_object('id', v_sale.id, 'bill_number', v_sale.bill_number,
                            'total_cents', v_subtotal - v_discount, 'replayed', false);
end;
$$;

comment on function public.pos_create_sale(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid) is
  'Staff. In-store bill from scanned units and quantity lines. Prices and the discount limit are enforced server-side; stock falls through the ledger.';

revoke all on function public.pos_create_sale(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid) from public, anon, service_role;
grant execute on function public.pos_create_sale(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 6. Customer returns: goods only, always into quarantine
-- ----------------------------------------------------------------------------
drop function if exists public.admin_return_pos_unit(uuid, text);

-- p_items: [{ "line_id": pos_sale_items.id | order_items.id, "unit_id"?: uuid,
--             "quantity": int, "condition": text }]
create or replace function public.admin_record_customer_return(
  p_source_type text,
  p_source_id   uuid,
  p_items       jsonb,
  p_note        text,
  p_request_id  uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_fingerprint text;
  v_return      public.customer_returns;
  v_sale        public.pos_sales;
  v_order       public.orders;
  v_item        jsonb;
  v_line_id     uuid;
  v_unit_id     uuid;
  v_qty         integer;
  v_condition   text;
  v_sale_item   public.pos_sale_items;
  v_order_item  public.order_items;
  v_unit        public.inventory_units;
  v_product_id  text;
  v_variant_id  uuid;
  v_name        text;
  v_vname       text;
  v_lot         uuid;
  v_label       text;
  v_count       integer := 0;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;
  if p_source_type is null or p_source_type not in ('pos', 'online') then
    raise exception 'invalid_source: choose a counter bill or an online order' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 200 then
    raise exception 'invalid_items: choose between 1 and 200 items' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object('type', p_source_type, 'source', p_source_id,
                                                          'items', p_items, 'note', v_note));
  select * into v_return from public.customer_returns where request_id = p_request_id;
  if found then
    if v_return.request_fingerprint <> v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different return' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_return.id, 'return_number', v_return.return_number, 'replayed', true);
  end if;

  -- Document first, which also serialises two returns against one sale.
  if p_source_type = 'pos' then
    select * into v_sale from public.pos_sales where id = p_source_id for update;
    if not found then
      raise exception 'unknown_sale: %', coalesce(p_source_id::text, '(missing)') using errcode = 'P0001';
    end if;
    v_label := 'bill ' || v_sale.bill_number;
  else
    select * into v_order from public.orders where id = p_source_id for update;
    if not found then
      raise exception 'unknown_order: %', coalesce(p_source_id::text, '(missing)') using errcode = 'P0001';
    end if;
    -- Goods that never left cannot come back: a reserved order is cancelled instead.
    if v_order.stock_state not in ('consumed', 'legacy_done', 'needs_reconciliation') then
      raise exception 'order_not_shipped: order % has not shipped, so there is nothing to return. Cancel it instead.', v_order.order_number
        using errcode = 'P0001';
    end if;
    v_label := 'order ' || v_order.order_number;
  end if;

  insert into public.customer_returns (return_number, source_type, pos_sale_id, order_id, note, created_by, request_id, request_fingerprint)
  values ('CR-' || lpad(nextval('private.customer_return_number_seq')::text, 6, '0'), p_source_type,
          case when p_source_type = 'pos' then v_sale.id end, case when p_source_type = 'online' then v_order.id end,
          v_note, v_uid, p_request_id, v_fingerprint)
  returning * into v_return;

  for v_item in select value from jsonb_array_elements(p_items) loop
    begin
      v_line_id := (v_item ->> 'line_id')::uuid;
      v_unit_id := nullif(v_item ->> 'unit_id', '')::uuid;
    exception when invalid_text_representation then
      raise exception 'invalid_items: malformed id' using errcode = '22023';
    end;
    if coalesce(jsonb_typeof(v_item -> 'quantity'), '') <> 'number'
       or coalesce(v_item ->> 'quantity', '') !~ '^[0-9]{1,4}$' or (v_item ->> 'quantity')::integer < 1 then
      raise exception 'invalid_quantity: the returned quantity must be a whole number' using errcode = '22023';
    end if;
    v_qty := (v_item ->> 'quantity')::integer;
    v_condition := v_item ->> 'condition';
    if v_condition is null or v_condition not in ('resaleable', 'opened', 'damaged', 'unverified') then
      raise exception 'invalid_condition: record the condition of each returned item' using errcode = '22023';
    end if;

    v_sale_item := null;
    v_order_item := null;
    if p_source_type = 'pos' then
      select * into v_sale_item from public.pos_sale_items
       where id = v_line_id and pos_sale_id = v_sale.id for update;
      if not found then
        raise exception 'unknown_line: that item is not on %', v_label using errcode = 'P0001';
      end if;
      if v_sale_item.returned_quantity + v_qty > v_sale_item.quantity then
        raise exception 'already_returned: only % of % can still be returned',
          v_sale_item.quantity - v_sale_item.returned_quantity, v_sale_item.product_name_snapshot using errcode = 'P0001';
      end if;
      v_product_id := v_sale_item.product_id;
      v_variant_id := v_sale_item.variant_id;
      v_name := v_sale_item.product_name_snapshot;
      v_vname := v_sale_item.variant_label_snapshot;
      -- A scanned line knows its unit.
      v_unit_id := coalesce(v_sale_item.unit_id, v_unit_id);
      update public.pos_sale_items
         set returned_quantity = returned_quantity + v_qty, returned_at = now(), return_note = v_note
       where id = v_sale_item.id;
    else
      select * into v_order_item from public.order_items
       where id = v_line_id and order_id = v_order.id for update;
      if not found then
        raise exception 'unknown_line: that item is not on %', v_label using errcode = 'P0001';
      end if;
      if v_order_item.returned_quantity + v_qty > v_order_item.quantity then
        raise exception 'already_returned: only % of % can still be returned',
          v_order_item.quantity - v_order_item.returned_quantity, v_order_item.product_name_snapshot using errcode = 'P0001';
      end if;
      v_product_id := v_order_item.product_id;
      v_variant_id := v_order_item.variant_id;
      v_name := v_order_item.product_name_snapshot;
      v_vname := v_order_item.variant_label_snapshot;
      update public.order_items set returned_quantity = returned_quantity + v_qty where id = v_order_item.id;
    end if;

    v_lot := null;
    if v_unit_id is not null then
      if v_qty <> 1 then
        raise exception 'invalid_quantity: a unit is returned one at a time' using errcode = '22023';
      end if;
      select * into v_unit from public.inventory_units where id = v_unit_id for update;
      if not found or v_unit.status <> 'sold'
         or (p_source_type = 'pos' and v_unit.pos_sale_id is distinct from v_sale.id)
         or (p_source_type = 'online' and v_unit.order_item_id is distinct from v_order_item.id) then
        raise exception 'unit_not_returnable: that unit was not sold on %', v_label using errcode = 'P0001';
      end if;
      update public.inventory_units
         set status = 'quarantined', location_code = 'QUARANTINE', status_changed_at = now(),
             status_note = left('Returned on ' || v_return.return_number || ' (' || v_condition || ')'
                                || coalesce(': ' || v_note, ''), 500)
       where id = v_unit.id;
    else
      if v_product_id is null then
        raise exception 'product_missing: % no longer exists, so it cannot be held in quarantine', v_name using errcode = 'P0001';
      end if;
      -- An online line of a unit-tracked item must name the exact unit.
      if p_source_type = 'online' and exists (
           select 1 from public.inventory_units u where u.order_item_id = v_order_item.id and u.status = 'sold') then
        raise exception 'unit_required: choose which unit of % came back', v_name using errcode = 'P0001';
      end if;
      insert into public.quarantine_lots (product_id, variant_id, quantity, open_quantity, customer_return_id, note)
      values (v_product_id, v_variant_id, v_qty, v_qty, v_return.id,
              left(v_condition || coalesce(': ' || v_note, ''), 500))
      returning id into v_lot;
    end if;

    insert into public.customer_return_items
      (customer_return_id, pos_sale_item_id, order_item_id, unit_id, quarantine_lot_id, product_id, variant_id,
       product_name_snapshot, variant_label_snapshot, quantity, condition)
    values (v_return.id, v_sale_item.id, v_order_item.id, v_unit_id, v_lot, v_product_id, v_variant_id,
            v_name, v_vname, v_qty, v_condition);

    v_count := v_count + v_qty;
  end loop;

  perform private.audit('customer_return', v_return.id::text, 'recorded', null,
                        jsonb_build_object('source', v_label, 'quantity', v_count), v_note);

  return jsonb_build_object('id', v_return.id, 'return_number', v_return.return_number, 'quantity', v_count, 'replayed', false);
end;
$$;

comment on function public.admin_record_customer_return(text, uuid, jsonb, text, uuid) is
  'Admin/owner. Goods came back from a customer. They go to quarantine; no money and no sellable stock move here.';

revoke all on function public.admin_record_customer_return(text, uuid, jsonb, text, uuid) from public, anon, service_role;
grant execute on function public.admin_record_customer_return(text, uuid, jsonb, text, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 7. Customer refunds: money only
-- ----------------------------------------------------------------------------
create or replace function public.admin_record_customer_refund(
  p_source_type        text,
  p_source_id          uuid,
  p_customer_return_id uuid,
  p_amount_cents       bigint,
  p_method             text,
  p_reference          text,
  p_note               text,
  p_request_id         uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_ref         text := nullif(btrim(coalesce(p_reference, '')), '');
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_fingerprint text;
  v_row         public.customer_refunds;
  v_total       bigint;
  v_refunded    bigint;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;
  if p_source_type is null or p_source_type not in ('pos', 'online') then
    raise exception 'invalid_source: choose a counter bill or an online order' using errcode = '22023';
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'invalid_amount: enter the amount refunded' using errcode = '22023';
  end if;
  if p_method is null or p_method not in ('cash', 'card', 'bank_transfer', 'other') then
    raise exception 'invalid_method: choose how the money was refunded' using errcode = '22023';
  end if;
  if v_ref is not null and length(v_ref) > 60 then
    raise exception 'invalid_reference: the reference is limited to 60 characters' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object(
    'type', p_source_type, 'source', p_source_id, 'return', p_customer_return_id, 'amount', p_amount_cents,
    'method', p_method, 'reference', v_ref, 'note', v_note));
  select * into v_row from public.customer_refunds where request_id = p_request_id;
  if found then
    if v_row.request_fingerprint <> v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different refund' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_row.id, 'refund_number', v_row.refund_number, 'replayed', true);
  end if;

  -- Locking the source serialises refunds against it, so the cap below holds.
  if p_source_type = 'pos' then
    select s.total_cents into v_total from public.pos_sales s where s.id = p_source_id for update;
    select coalesce(sum(r.amount_cents), 0) into v_refunded from public.customer_refunds r where r.pos_sale_id = p_source_id;
  else
    select o.total_cents into v_total from public.orders o where o.id = p_source_id for update;
    select coalesce(sum(r.amount_cents), 0) into v_refunded from public.customer_refunds r where r.order_id = p_source_id;
  end if;
  if v_total is null then
    raise exception 'unknown_sale: %', coalesce(p_source_id::text, '(missing)') using errcode = 'P0001';
  end if;
  if v_refunded + p_amount_cents > v_total then
    raise exception 'refund_exceeds_paid: % cents of % have already been refunded', v_refunded, v_total using errcode = 'P0001';
  end if;

  if p_customer_return_id is not null and not exists (
       select 1 from public.customer_returns cr
        where cr.id = p_customer_return_id
          and ((p_source_type = 'pos' and cr.pos_sale_id = p_source_id)
               or (p_source_type = 'online' and cr.order_id = p_source_id))) then
    raise exception 'unknown_return: that return does not belong to this sale' using errcode = 'P0001';
  end if;

  insert into public.customer_refunds (refund_number, source_type, pos_sale_id, order_id, customer_return_id,
                                       amount_cents, method, reference, note, created_by, request_id, request_fingerprint)
  values ('RF-' || lpad(nextval('private.customer_refund_number_seq')::text, 6, '0'), p_source_type,
          case when p_source_type = 'pos' then p_source_id end, case when p_source_type = 'online' then p_source_id end,
          p_customer_return_id, p_amount_cents, p_method, v_ref, v_note, v_uid, p_request_id, v_fingerprint)
  returning * into v_row;

  return jsonb_build_object('id', v_row.id, 'refund_number', v_row.refund_number, 'replayed', false);
end;
$$;

comment on function public.admin_record_customer_refund(text, uuid, uuid, bigint, text, text, text, uuid) is
  'Admin/owner. Money went back to a customer. Capped at what was charged; moves no stock.';

revoke all on function public.admin_record_customer_refund(text, uuid, uuid, bigint, text, text, text, uuid) from public, anon, service_role;
grant execute on function public.admin_record_customer_refund(text, uuid, uuid, bigint, text, text, text, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 8. Quarantine: in, and back out only by a person's decision
-- ----------------------------------------------------------------------------
-- A shelf unit going to quarantine leaves the sellable number.
create or replace function public.admin_quarantine_units(p_unit_ids uuid[], p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note     text := btrim(coalesce(p_note, ''));
  v_products text[];
  v_unit     public.inventory_units;
  v_holder   record;
  v_count    integer := 0;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_unit_ids is null or cardinality(p_unit_ids) = 0 or cardinality(p_unit_ids) > 500 then
    raise exception 'invalid_items: choose between 1 and 500 units' using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  select array_agg(u.product_id) into v_products from public.inventory_units u where u.id = any (p_unit_ids);
  perform private.lock_products(coalesce(v_products, '{}'::text[]));

  for v_unit in
    select * from public.inventory_units where id = any (p_unit_ids) order by barcode for update
  loop
    if v_unit.status <> 'in_stock' then
      raise exception 'unit_not_available: % is % and cannot be quarantined', v_unit.barcode, replace(v_unit.status, '_', ' ')
        using errcode = 'P0001';
    end if;
    update public.inventory_units
       set status = 'quarantined', location_code = 'QUARANTINE', status_changed_at = now(), status_note = v_note
     where id = v_unit.id;
    v_count := v_count + 1;
  end loop;

  if v_count <> cardinality(p_unit_ids) then
    raise exception 'unit_not_found: % of the chosen units do not exist', cardinality(p_unit_ids) - v_count using errcode = 'P0001';
  end if;

  for v_holder in
    select u.product_id, u.variant_id, count(*)::integer as qty
      from public.inventory_units u where u.id = any (p_unit_ids)
     group by u.product_id, u.variant_id order by u.product_id, u.variant_id
  loop
    perform private.move_stock(v_holder.product_id, v_holder.variant_id, -v_holder.qty, 'quarantine',
                               'Quarantined: ' || v_note, null, null, null);
  end loop;

  return jsonb_build_object('quarantined', v_count);
end;
$$;

-- Verified fit to sell: back on the shelf, into the number, oldest-first as before.
create or replace function public.admin_release_quarantine_units(p_unit_ids uuid[], p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note     text := btrim(coalesce(p_note, ''));
  v_products text[];
  v_unit     public.inventory_units;
  v_holder   record;
  v_count    integer := 0;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_unit_ids is null or cardinality(p_unit_ids) = 0 or cardinality(p_unit_ids) > 500 then
    raise exception 'invalid_items: choose between 1 and 500 units' using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note saying how it was verified is required' using errcode = '22023';
  end if;

  select array_agg(u.product_id) into v_products from public.inventory_units u where u.id = any (p_unit_ids);
  perform private.lock_products(coalesce(v_products, '{}'::text[]));

  for v_unit in
    select * from public.inventory_units where id = any (p_unit_ids) order by barcode for update
  loop
    if v_unit.status <> 'quarantined' then
      raise exception 'unit_not_available: % is not in quarantine', v_unit.barcode using errcode = 'P0001';
    end if;
    update public.inventory_units
       set status = 'in_stock', location_code = 'MAIN_SHOP', order_id = null, order_item_id = null, pos_sale_id = null,
           status_changed_at = now(), status_note = 'Verified: ' || left(v_note, 480)
     where id = v_unit.id;
    v_count := v_count + 1;
  end loop;

  if v_count <> cardinality(p_unit_ids) then
    raise exception 'unit_not_found: % of the chosen units do not exist', cardinality(p_unit_ids) - v_count using errcode = 'P0001';
  end if;

  for v_holder in
    select u.product_id, u.variant_id, count(*)::integer as qty
      from public.inventory_units u where u.id = any (p_unit_ids)
     group by u.product_id, u.variant_id order by u.product_id, u.variant_id
  loop
    perform private.move_stock(v_holder.product_id, v_holder.variant_id, v_holder.qty, 'quarantine_release',
                               'Released from quarantine: ' || v_note, null, null, null);
  end loop;

  return jsonb_build_object('released', v_count);
end;
$$;

-- p_expected_open makes a double-submitted decision fail instead of applying twice.
create or replace function public.admin_resolve_quarantine_lot(
  p_lot_id        uuid,
  p_expected_open integer,
  p_release       integer,
  p_write_off     integer,
  p_note          text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note    text := btrim(coalesce(p_note, ''));
  v_release integer := coalesce(p_release, 0);
  v_off     integer := coalesce(p_write_off, 0);
  v_lot     public.quarantine_lots;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;
  if v_release < 0 or v_off < 0 or v_release + v_off = 0 then
    raise exception 'invalid_quantity: enter how many to release or write off' using errcode = '22023';
  end if;

  select * into v_lot from public.quarantine_lots where id = p_lot_id;
  if not found then
    raise exception 'unknown_lot: %', coalesce(p_lot_id::text, '(missing)') using errcode = 'P0001';
  end if;

  perform private.lock_products(array[v_lot.product_id]);
  select * into v_lot from public.quarantine_lots where id = p_lot_id for update;

  if v_lot.open_quantity is distinct from p_expected_open then
    raise exception 'stale_quantity: this lot now has % waiting, not %', v_lot.open_quantity, p_expected_open using errcode = 'P0001';
  end if;
  if v_release + v_off > v_lot.open_quantity then
    raise exception 'invalid_quantity: only % are waiting', v_lot.open_quantity using errcode = '22023';
  end if;
  if v_release > 0 and private.tracking_mode_of(v_lot.product_id, v_lot.variant_id) = 'unit' then
    raise exception 'lot_release_requires_grn: this item is now tracked individually. Receive it as a buy-back so it gets a barcode, and write this lot off.'
      using errcode = 'P0001';
  end if;

  update public.quarantine_lots
     set open_quantity = open_quantity - v_release - v_off,
         released_quantity = released_quantity + v_release,
         written_off_quantity = written_off_quantity + v_off
   where id = v_lot.id;

  if v_release > 0 then
    perform private.move_stock(v_lot.product_id, v_lot.variant_id, v_release, 'quarantine_release',
                               'Released from quarantine: ' || v_note, null, null, null);
  end if;

  perform private.audit('quarantine_lot', v_lot.id::text, 'resolved',
                        jsonb_build_object('open_quantity', v_lot.open_quantity),
                        jsonb_build_object('released', v_release, 'written_off', v_off), v_note);

  return jsonb_build_object('id', v_lot.id, 'released', v_release, 'written_off', v_off);
end;
$$;

revoke all on function public.admin_quarantine_units(uuid[], text) from public, anon, service_role;
revoke all on function public.admin_release_quarantine_units(uuid[], text) from public, anon, service_role;
revoke all on function public.admin_resolve_quarantine_lot(uuid, integer, integer, integer, text) from public, anon, service_role;
grant execute on function public.admin_quarantine_units(uuid[], text) to authenticated;
grant execute on function public.admin_release_quarantine_units(uuid[], text) to authenticated;
grant execute on function public.admin_resolve_quarantine_lot(uuid, integer, integer, integer, text) to authenticated;

-- A pre-rollout order line flagged at shipment: a person records what was done.
create or replace function public.admin_resolve_stock_flag(p_flag_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text := btrim(coalesce(p_note, ''));
  v_flag public.stock_reconciliation_flags;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;
  select * into v_flag from public.stock_reconciliation_flags where id = p_flag_id for update;
  if not found then
    raise exception 'unknown_flag: %', coalesce(p_flag_id::text, '(missing)') using errcode = 'P0001';
  end if;
  if v_flag.resolved_at is not null then
    raise exception 'flag_resolved: this has already been resolved' using errcode = 'P0001';
  end if;
  update public.stock_reconciliation_flags
     set resolved_at = now(), resolved_by = (select auth.uid()), resolution_note = v_note
   where id = v_flag.id;
  return jsonb_build_object('id', v_flag.id, 'resolved', true);
end;
$$;

revoke all on function public.admin_resolve_stock_flag(uuid, text) from public, anon, service_role;
grant execute on function public.admin_resolve_stock_flag(uuid, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 9. Self-verification
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['pos_discount_approvals', 'customer_returns', 'customer_return_items',
                           'customer_refunds', 'quarantine_lots'] loop
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

  if has_function_privilege('anon', 'public.pos_create_sale(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_record_customer_refund(text, uuid, uuid, bigint, text, text, text, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.tier_of_profile(uuid)', 'EXECUTE') then
    raise exception 'verify: function grants are wrong';
  end if;

  raise notice 'verified: counter, returns and refunds write only through functions';
end
$$;
