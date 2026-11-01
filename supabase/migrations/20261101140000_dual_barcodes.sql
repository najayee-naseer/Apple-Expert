-- ============================================================================
-- Apple Expert · dual barcodes
-- ----------------------------------------------------------------------------
-- Two kinds of barcode, one lookup:
--
--   unit     AE00000001  one physical item (inventory_units, exists already)
--   product  AP00000001  one product/variant, the same on every item; issued by
--                        the shop on request for quantity-tracked accessories
--                        and parts. A manufacturer's UPC-A / EAN / GTIN can also
--                        be registered, resolving to the same product/variant.
--
-- Barcodes only identify things. Nothing here moves stock: a sale still goes
-- through pos_create_sale -> move_stock -> the ledger and the P1 guard.
--
-- UNIQUENESS
--   barcode_registry holds every barcode ever issued or registered, of either
--   kind, in one primary key. Rows are never removed, so a retired barcode can
--   never be reused. Serial numbers are not in it (one device can recur across
--   re-entries), so they are checked against it in both directions instead.
--
-- DECISIONS (approved by the owner)
--   * Shared barcodes only for accessories and parts. iPhone, iPad, Mac, Apple
--     Watch and AirPods use unit barcodes only: categories.allows_shared_barcode
--     is an allow-list, so a new category starts blocked.
--   * Shop codes are issued on request. There is no bulk issue, and this
--     migration creates none.
--
-- WHAT THIS DOES NOT TOUCH
--   No stock value, tracking mode, GRN, unit, order, sale or supplier row. The
--   registry is filled only from barcodes that already exist on inventory_units.
--   pos_create_sale and move_stock are not replaced.
--
-- SUPPORTED MANUFACTURER FORMATS: EAN-8, UPC-A, EAN-13, GTIN-14. Not UPC-E, whose
-- 8 digits are a compressed UPC-A and cannot be told from EAN-8 without expanding.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Pre-flight
-- ----------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.admin_receive_goods(text, uuid, text, uuid, text, boolean, text, date, text, jsonb, uuid)') is null then
    raise exception 'pre-flight: apply 20261101110000 first';
  end if;
  if to_regprocedure('public.pos_quote_product(text, uuid, uuid)') is null then
    raise exception 'pre-flight: apply 20261101120000 first';
  end if;
end
$$;


-- ----------------------------------------------------------------------------
-- 1. Which categories may have shared barcodes
-- ----------------------------------------------------------------------------
alter table public.categories
  add column allows_shared_barcode boolean not null default false;

comment on column public.categories.allows_shared_barcode is
  'True only for accessories and parts. Changed only by migration: every other category uses unit barcodes.';

-- Also emitted by scripts/generate-seed.mjs: locally migrations run before the seed.
update public.categories set allows_shared_barcode = true
 where slug in ('accessories', 'parts', 'batteries', 'displays');

-- SECURITY INVOKER: current_user is the API role for a direct request.
create or replace function private.guard_shared_barcode_flag()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated', 'service_role') then
    if tg_op = 'INSERT' then
      new.allows_shared_barcode := false;
    elsif new.allows_shared_barcode is distinct from old.allows_shared_barcode then
      raise exception 'shared_barcode_locked: which categories may have shared barcodes is not editable here'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger categories_guard_shared_barcode
  before insert or update of allows_shared_barcode on public.categories
  for each row execute function private.guard_shared_barcode_flag();


-- ----------------------------------------------------------------------------
-- 2. Tables
-- ----------------------------------------------------------------------------
create sequence private.product_barcode_seq maxvalue 99999999;
revoke all on sequence private.product_barcode_seq from public;

-- lpad() would cut a 9-digit number short. The unique key already refuses the
-- resulting duplicate; this makes running out a clear error instead.
alter sequence private.inventory_unit_barcode_seq maxvalue 99999999;

create table public.product_barcodes (
  id           uuid primary key default gen_random_uuid(),
  product_id   text not null references public.products (id) on delete restrict,
  -- NULL for a product sold without variants.
  variant_id   uuid,
  value        text not null,
  source       text not null check (source in ('shop', 'manufacturer')),
  status       text not null default 'active' check (status in ('active', 'retired')),
  retire_note  text check (retire_note is null or length(retire_note) between 3 and 500),
  retired_by   uuid references public.profiles (id) on delete set null,
  retired_at   timestamptz,
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint product_barcodes_variant_fk
    foreign key (variant_id, product_id)
    references public.product_variants (id, product_id) on delete restrict,
  constraint product_barcodes_value_format check (
    (source = 'shop' and value ~ '^AP[0-9]{8,}$')
    or (source = 'manufacturer' and value ~ '^([0-9]{8}|[0-9]{12,14})$')),
  constraint product_barcodes_retired_complete check ((status = 'retired') = (retired_at is not null))
);

-- At most one current shop code per product/variant; manufacturer codes may be several.
create unique index product_barcodes_one_active_shop_key on public.product_barcodes (product_id, variant_id)
  nulls not distinct
  where source = 'shop' and status = 'active';
create index product_barcodes_product_idx on public.product_barcodes (product_id, variant_id);

comment on table public.product_barcodes is
  'Shared barcodes of quantity-tracked accessories and parts. Staff read; written only by SECURITY DEFINER functions; never deleted, only retired.';

create table public.barcode_registry (
  -- Canonical form: see private.canonical_code().
  value              text primary key,
  kind               text not null check (kind in ('unit', 'product')),
  unit_id            uuid unique references public.inventory_units (id) on delete restrict,
  product_barcode_id uuid unique references public.product_barcodes (id) on delete restrict,
  created_at         timestamptz not null default now(),
  constraint barcode_registry_one_target check (
    (kind = 'unit' and unit_id is not null and product_barcode_id is null)
    or (kind = 'product' and product_barcode_id is not null and unit_id is null))
);

comment on table public.barcode_registry is
  'Every barcode ever issued, of either kind. The primary key is what keeps values globally unique, and rows stay after retirement so no value is reused.';

alter table public.product_barcodes enable row level security;
alter table public.barcode_registry enable row level security;

create policy "product_barcodes staff read" on public.product_barcodes
  for select to authenticated using (private.has_role('staff'));
create policy "barcode_registry staff read" on public.barcode_registry
  for select to authenticated using (private.has_role('staff'));

revoke all on public.product_barcodes, public.barcode_registry from anon;
revoke insert, update, delete, truncate on public.product_barcodes, public.barcode_registry from authenticated, service_role;
grant select on public.product_barcodes, public.barcode_registry to authenticated;


-- ----------------------------------------------------------------------------
-- 3. Helpers
-- ----------------------------------------------------------------------------
-- Upper case, no spaces. A UPC-A and the EAN-13 with a leading zero are one
-- product and scanners output either, so numeric barcode lengths compare as GTIN-14.
create or replace function private.canonical_code(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when v ~ '^([0-9]{8}|[0-9]{12,14})$' then lpad(v, 14, '0')
    else v
  end
  from (select private.normalize_serial(p_value) as v) t
$$;

-- The GS1 check digit, for EAN-8, UPC-A, EAN-13 and GTIN-14.
create or replace function private.gtin_valid(p_value text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_sum    integer := 0;
  v_length integer;
  i        integer;
begin
  if p_value is null or p_value !~ '^([0-9]{8}|[0-9]{12,14})$' then
    return false;
  end if;
  v_length := length(p_value);
  for i in 1..v_length - 1 loop
    v_sum := v_sum + substr(p_value, v_length - i, 1)::integer * case when i % 2 = 1 then 3 else 1 end;
  end loop;
  return (10 - v_sum % 10) % 10 = substr(p_value, v_length, 1)::integer;
end;
$$;

-- What every issue and registration must satisfy. The caller holds the product lock.
create or replace function private.check_shared_barcode_item(p_product_id text, p_variant_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_product  public.products;
  v_allowed  boolean;
begin
  select * into v_product from public.products where id = p_product_id;
  if not found then
    raise exception 'unknown_product: %', coalesce(p_product_id, '(missing)') using errcode = 'P0001';
  end if;

  if p_variant_id is not null then
    perform 1 from public.product_variants v where v.id = p_variant_id and v.product_id = p_product_id;
    if not found then
      raise exception 'variant_product_mismatch: that variant does not belong to %', p_product_id using errcode = 'P0001';
    end if;
  elsif exists (select 1 from public.product_variants v where v.product_id = p_product_id) then
    raise exception 'variant_required: choose the variant for %', v_product.name using errcode = 'P0001';
  end if;

  select c.allows_shared_barcode into v_allowed from public.categories c where c.id = v_product.category_id;
  if not coalesce(v_allowed, false) then
    raise exception 'shared_barcode_not_allowed: % must use individual unit barcodes', v_product.name using errcode = 'P0001';
  end if;

  if private.tracking_mode_of(p_product_id, p_variant_id) <> 'quantity' then
    raise exception 'shared_barcode_not_allowed: % is tracked individually, so each item has its own barcode', v_product.name
      using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function private.guard_shared_barcode_flag() from public, anon, authenticated, service_role;
revoke all on function private.canonical_code(text) from public, anon, authenticated, service_role;
revoke all on function private.gtin_valid(text) from public, anon, authenticated, service_role;
revoke all on function private.check_shared_barcode_item(text, uuid) from public, anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 4. The registry fills itself; history cannot be rewritten
-- ----------------------------------------------------------------------------
create or replace function private.register_unit_barcode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.barcode_registry (value, kind, unit_id) values (new.barcode, 'unit', new.id);
  return null;
end;
$$;

create or replace function private.register_product_barcode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.barcode_registry (value, kind, product_barcode_id)
  values (private.canonical_code(new.value), 'product', new.id);
  return null;
end;
$$;

-- A serial that equals a barcode would make a scan ambiguous.
create or replace function private.guard_unit_serial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.serial_number is not null then
    if new.serial_number ~ '^A[EP][0-9]{8,}$' then
      raise exception 'invalid_serial: "%" looks like one of this shop''s own barcodes, not an IMEI / serial', new.serial_number
        using errcode = '22023';
    end if;
    if exists (select 1 from public.barcode_registry r
                where r.value = private.canonical_code(new.serial_number) and r.kind = 'product') then
      raise exception 'invalid_serial: "%" is already registered as a product barcode', new.serial_number
        using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;

-- SECURITY INVOKER, like the stock guard: a request through the API is never an
-- operator session, even from inside a SECURITY DEFINER function. Only the
-- operator can delete, which test cleanup and a disaster restore need.
create or replace function private.guard_barcode_history()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_operator boolean := pg_catalog.pg_has_role(session_user, 'postgres', 'MEMBER')
                        and current_user not in ('anon', 'authenticated', 'service_role');
begin
  if tg_op = 'DELETE' then
    if v_operator then
      return old;
    end if;
    raise exception 'barcode_history: a barcode is never deleted; retire it instead' using errcode = '42501';
  end if;

  if tg_table_name = 'barcode_registry' then
    raise exception 'barcode_history: the barcode registry cannot be changed' using errcode = '42501';
  end if;

  if new.value is distinct from old.value
     or new.source is distinct from old.source
     or new.product_id is distinct from old.product_id
     or new.variant_id is distinct from old.variant_id then
    raise exception 'barcode_history: a barcode never changes what it identifies' using errcode = '42501';
  end if;
  if old.status = 'retired' and new.status <> 'retired' then
    raise exception 'barcode_retired: a retired barcode is never used again' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.register_unit_barcode() from public, anon, authenticated, service_role;
revoke all on function private.register_product_barcode() from public, anon, authenticated, service_role;
revoke all on function private.guard_unit_serial() from public, anon, authenticated, service_role;
revoke all on function private.guard_barcode_history() from public, anon, authenticated, service_role;

create trigger inventory_units_register_barcode
  after insert on public.inventory_units
  for each row execute function private.register_unit_barcode();

create trigger inventory_units_guard_serial
  before insert on public.inventory_units
  for each row execute function private.guard_unit_serial();

create trigger product_barcodes_register
  after insert on public.product_barcodes
  for each row execute function private.register_product_barcode();

create trigger product_barcodes_guard_history
  before update or delete on public.product_barcodes
  for each row execute function private.guard_barcode_history();

create trigger barcode_registry_guard_history
  before update or delete on public.barcode_registry
  for each row execute function private.guard_barcode_history();

-- Existing barcodes only. Nothing is created for units or products without one.
insert into public.barcode_registry (value, kind, unit_id)
select u.barcode, 'unit', u.id from public.inventory_units u;


-- ----------------------------------------------------------------------------
-- 5. Issuing, registering and retiring
-- ----------------------------------------------------------------------------
-- On request, for one item. Asking again returns the current code.
create or replace function public.admin_issue_product_barcode(p_product_id text, p_variant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.product_barcodes;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;

  -- The product lock serialises two people issuing for one item.
  perform private.lock_products(array[p_product_id]);
  perform private.check_shared_barcode_item(p_product_id, p_variant_id);

  select * into v_row from public.product_barcodes b
   where b.product_id = p_product_id and b.variant_id is not distinct from p_variant_id
     and b.source = 'shop' and b.status = 'active';
  if found then
    return jsonb_build_object('id', v_row.id, 'value', v_row.value, 'source', v_row.source, 'created', false);
  end if;

  insert into public.product_barcodes (product_id, variant_id, value, source, created_by)
  values (p_product_id, p_variant_id,
          'AP' || lpad(nextval('private.product_barcode_seq')::text, 8, '0'), 'shop', v_uid)
  returning * into v_row;

  perform private.audit('product_barcode', v_row.id::text, 'issued', null,
                        jsonb_build_object('value', v_row.value, 'product_id', p_product_id, 'variant_id', p_variant_id), null);

  return jsonb_build_object('id', v_row.id, 'value', v_row.value, 'source', v_row.source, 'created', true);
end;
$$;

create or replace function public.admin_register_manufacturer_barcode(p_product_id text, p_variant_id uuid, p_value text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_value     text := private.normalize_serial(p_value);
  v_canonical text;
  v_existing  public.product_barcodes;
  v_kind      text;
  v_row       public.product_barcodes;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if not private.gtin_valid(v_value) then
    raise exception 'invalid_barcode: "%" is not a valid EAN-8, UPC-A, EAN-13 or GTIN-14 (check the digits)', coalesce(v_value, '') using errcode = '22023';
  end if;

  perform private.lock_products(array[p_product_id]);
  perform private.check_shared_barcode_item(p_product_id, p_variant_id);

  v_canonical := private.canonical_code(v_value);

  select r.kind into v_kind from public.barcode_registry r where r.value = v_canonical;
  if found then
    select b.* into v_existing from public.barcode_registry r
      join public.product_barcodes b on b.id = r.product_barcode_id
     where r.value = v_canonical;
    if v_existing.id is not null and v_existing.status = 'retired' then
      raise exception 'barcode_retired: % was retired and is never used again', v_value using errcode = 'P0001';
    end if;
    if v_existing.id is not null and v_existing.product_id = p_product_id
       and v_existing.variant_id is not distinct from p_variant_id then
      return jsonb_build_object('id', v_existing.id, 'value', v_existing.value, 'source', v_existing.source, 'created', false);
    end if;
    raise exception 'barcode_in_use: % already belongs to another item', v_value using errcode = 'P0001';
  end if;

  -- A serial equal to this code would make a scan ambiguous.
  if exists (select 1 from public.inventory_units u
              where u.serial_number is not null and private.canonical_code(u.serial_number) = v_canonical) then
    raise exception 'barcode_in_use: % is already recorded as a device serial number', v_value using errcode = 'P0001';
  end if;

  insert into public.product_barcodes (product_id, variant_id, value, source, created_by)
  values (p_product_id, p_variant_id, v_value, 'manufacturer', v_uid)
  returning * into v_row;

  perform private.audit('product_barcode', v_row.id::text, 'registered', null,
                        jsonb_build_object('value', v_row.value, 'product_id', p_product_id, 'variant_id', p_variant_id), null);

  return jsonb_build_object('id', v_row.id, 'value', v_row.value, 'source', v_row.source, 'created', true);
end;
$$;

-- The value stays in the registry for good, so it can never come back.
create or replace function public.admin_retire_product_barcode(p_barcode_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_note text := btrim(coalesce(p_note, ''));
  v_row  public.product_barcodes;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  select * into v_row from public.product_barcodes where id = p_barcode_id for update;
  if not found then
    raise exception 'unknown_barcode: %', coalesce(p_barcode_id::text, '(missing)') using errcode = 'P0001';
  end if;
  if v_row.status = 'retired' then
    raise exception 'barcode_retired: % is already retired', v_row.value using errcode = 'P0001';
  end if;

  update public.product_barcodes
     set status = 'retired', retired_at = now(), retired_by = v_uid, retire_note = v_note
   where id = v_row.id;

  perform private.audit('product_barcode', v_row.id::text, 'retired',
                        jsonb_build_object('value', v_row.value), null, v_note);

  return jsonb_build_object('id', v_row.id, 'value', v_row.value, 'status', 'retired');
end;
$$;

revoke all on function public.admin_issue_product_barcode(text, uuid) from public, anon, service_role;
revoke all on function public.admin_register_manufacturer_barcode(text, uuid, text) from public, anon, service_role;
revoke all on function public.admin_retire_product_barcode(uuid, text) from public, anon, service_role;
grant execute on function public.admin_issue_product_barcode(text, uuid) to authenticated;
grant execute on function public.admin_register_manufacturer_barcode(text, uuid, text) to authenticated;
grant execute on function public.admin_retire_product_barcode(uuid, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 6. What a scan means
-- ----------------------------------------------------------------------------
-- A unit is returned whatever its status, so the counter can say why it cannot be
-- sold; pos_create_sale re-checks it under lock. Prices come from the existing
-- functions at the served customer's tier. No cost is ever in the result.
create or replace function public.pos_scan(p_code text, p_customer_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code     text := private.normalize_serial(p_code);
  v_entry    public.barcode_registry;
  v_barcode  public.product_barcodes;
  v_unit     public.inventory_units;
  v_newer    text;
  v_next     uuid;
  v_result   jsonb;
begin
  if (select auth.uid()) is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if v_code is null or length(v_code) > 40 then
    raise exception 'unit_not_found: nothing was scanned' using errcode = 'P0001';
  end if;

  select * into v_entry from public.barcode_registry r where r.value = private.canonical_code(v_code);

  if found and v_entry.kind = 'product' then
    select * into v_barcode from public.product_barcodes b where b.id = v_entry.product_barcode_id;
    if v_barcode.status = 'retired' then
      raise exception 'barcode_retired: % is no longer in use. Replace this label.', v_code using errcode = 'P0001';
    end if;
    -- Rechecked here: tracking mode and category can both change after issue.
    if private.tracking_mode_of(v_barcode.product_id, v_barcode.variant_id) <> 'quantity'
       or not coalesce((select c.allows_shared_barcode from public.products p
                          join public.categories c on c.id = p.category_id
                         where p.id = v_barcode.product_id), false) then
      raise exception 'scan_required: this item now uses individual barcodes. Scan its own barcode or IMEI.' using errcode = 'P0001';
    end if;
    return public.pos_quote_product(v_barcode.product_id, v_barcode.variant_id, p_customer_profile_id)
           || jsonb_build_object('barcode', v_barcode.value);
  end if;

  if found then
    select * into v_unit from public.inventory_units u where u.id = v_entry.unit_id;
  else
    select * into v_unit from private.find_unit_by_code(v_code);
  end if;
  if v_unit.id is null then
    raise exception 'unit_not_found: no item with barcode or IMEI %', v_code using errcode = 'P0001';
  end if;

  v_result := public.pos_lookup_unit(v_unit.barcode, p_customer_profile_id);

  -- An old sticker left on a device that came back: name the barcode it has now.
  v_next := v_unit.id;
  loop
    select u.id, u.barcode into v_next, v_newer from public.inventory_units u
     where u.reentry_of_unit_id = v_next
     order by u.created_at desc limit 1;
    exit when not found;
    v_result := v_result || jsonb_build_object('reentered_as', v_newer);
  end loop;

  return v_result;
end;
$$;

comment on function public.pos_scan(text, uuid) is
  'Staff. Resolves a scan to one exact unit (by barcode or serial) or one exact product/variant. Identifies only: selling is still pos_create_sale.';

revoke all on function public.pos_scan(text, uuid) from public, anon, service_role;
grant execute on function public.pos_scan(text, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 7. Self-verification
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['product_barcodes', 'barcode_registry'] loop
    if has_table_privilege('anon', 'public.' || t, 'SELECT')
       or has_table_privilege('authenticated', 'public.' || t, 'INSERT')
       or has_table_privilege('authenticated', 'public.' || t, 'UPDATE')
       or has_table_privilege('authenticated', 'public.' || t, 'DELETE')
       or has_table_privilege('service_role', 'public.' || t, 'INSERT')
       or has_table_privilege('service_role', 'public.' || t, 'UPDATE')
       or has_table_privilege('service_role', 'public.' || t, 'DELETE') then
      raise exception 'verify: a client role can write % (or anon can read it)', t;
    end if;
    if not (select relrowsecurity from pg_class where oid = ('public.' || t)::regclass) then
      raise exception 'verify: RLS is off on %', t;
    end if;
  end loop;

  if has_function_privilege('anon', 'public.pos_scan(text, uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_issue_product_barcode(text, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.canonical_code(text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.check_shared_barcode_item(text, uuid)', 'EXECUTE') then
    raise exception 'verify: function grants are wrong';
  end if;

  if exists (select 1 from public.categories
              where allows_shared_barcode and slug in ('iphone', 'ipad', 'mac', 'watch', 'airpods')) then
    raise exception 'verify: a device category allows shared barcodes';
  end if;

  if (select count(*) from public.barcode_registry) <> (select count(*) from public.inventory_units)
     or exists (select 1 from public.product_barcodes) then
    raise exception 'verify: the registry must hold existing unit barcodes and nothing else';
  end if;

  if has_column_privilege('authenticated', 'public.inventory_units', 'unit_cost_cents', 'SELECT') then
    raise exception 'verify: purchase cost became readable';
  end if;

  raise notice 'verified: barcodes read-only for clients; device categories blocked; no barcode created';
end
$$;


-- ----------------------------------------------------------------------------
-- Rollback (manual, and only before any label has been printed: after that the
-- values are on physical items and must stay reserved).
--   drop function public.pos_scan(text, uuid);
--   drop function public.admin_retire_product_barcode(uuid, text);
--   drop function public.admin_register_manufacturer_barcode(text, uuid, text);
--   drop function public.admin_issue_product_barcode(text, uuid);
--   drop trigger inventory_units_register_barcode on public.inventory_units;
--   drop trigger inventory_units_guard_serial on public.inventory_units;
--   drop table public.barcode_registry;
--   drop table public.product_barcodes;
--   drop function private.register_unit_barcode(), private.register_product_barcode(),
--     private.guard_unit_serial(), private.guard_barcode_history(),
--     private.check_shared_barcode_item(text, uuid), private.gtin_valid(text),
--     private.canonical_code(text);
--   drop sequence private.product_barcode_seq;
--   alter sequence private.inventory_unit_barcode_seq no maxvalue;
--   drop trigger categories_guard_shared_barcode on public.categories;
--   drop function private.guard_shared_barcode_flag();
--   alter table public.categories drop column allows_shared_barcode;
-- ----------------------------------------------------------------------------
