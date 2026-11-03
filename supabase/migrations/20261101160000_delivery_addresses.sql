-- ============================================================================
-- Apple Expert · saved delivery addresses and the order address snapshot
-- ----------------------------------------------------------------------------
-- Saved addresses and an order's delivery address are two separate things:
--
--   public.addresses         the customer's address book. It can change.
--   orders.shipping_address  a copy taken when the order is placed. It cannot.
--
-- Both already existed and nothing used them, so this migration extends them.
-- No column is dropped or renamed and no existing row is rewritten.
--
-- What it adds
--   * addresses: recipient_name, province, landmark, delivery_instructions,
--     country_code, an index, and a validation trigger.
--   * delivery_regions: the province and district reference. Delivery to another
--     country is opened by inserting its rows here, with no code change.
--   * save_address / set_default_address / delete_address: one transaction each,
--     serialised on the customer's profile row. The existing partial unique index
--     addresses_one_default_uq remains the guarantee of one default per customer.
--   * place_order_v3: the only way left to place an online order. It checks the
--     address belongs to the caller and writes the snapshot in the order's own
--     transaction, so either both exist or neither does.
--   * orders_protect_shipping_address: a snapshot cannot be changed once written,
--     by anyone, including SECURITY DEFINER code and the service role.
--   * order_delivery_notes: staff-only delivery notes. A separate table, because
--     customers can read their whole orders row under "orders read own", and
--     orders.notes holds what the customer wrote.
--   * admin_order_account_phone: the verified sign-in number, for staff, by order.
--
-- Decisions to review (none is hidden behind a default)
--   * Town and city stay free text. The repo has no reliable Sri Lankan town
--     dataset and a partial list would refuse real addresses. Provinces and
--     districts are a fixed, official list, so those are enforced.
--   * place_order and place_order_v2 now REFUSE with address_required. They have
--     no way to carry an address, and an order must not exist without one. Apps
--     already installed therefore cannot order until they are updated, so this
--     migration and the new APK have to be released together.
--   * "addresses staff read" is dropped. It let any staff member read every
--     customer's whole address book, nothing in the app used it, and staff keep
--     order delivery details through "orders staff read". Restore with:
--       create policy "addresses staff read" on public.addresses
--         for select to authenticated using (private.has_role('staff'));
--   * Existing orders have no snapshot and keep none: no delivery address was
--     ever recorded for them, and copying a current address in would be invented
--     history. The screens say that no address was recorded.
--   * Existing address rows, if any, are not guessed at. They cannot be used at
--     checkout (address_incomplete) until the customer completes them.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Reference data
-- ----------------------------------------------------------------------------
create table public.delivery_regions (
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  country_name text not null,
  province     text not null,
  district     text not null,
  primary key (country_code, province, district)
);

comment on table public.delivery_regions is
  'Where delivery is offered. A country with no rows here cannot be saved as an address.';

insert into public.delivery_regions (country_code, country_name, province, district)
select 'LK', 'Sri Lanka', r.province, r.district
from (values
  ('Central Province',       'Kandy'),
  ('Central Province',       'Matale'),
  ('Central Province',       'Nuwara Eliya'),
  ('Eastern Province',       'Ampara'),
  ('Eastern Province',       'Batticaloa'),
  ('Eastern Province',       'Trincomalee'),
  ('North Central Province', 'Anuradhapura'),
  ('North Central Province', 'Polonnaruwa'),
  ('North Western Province', 'Kurunegala'),
  ('North Western Province', 'Puttalam'),
  ('Northern Province',      'Jaffna'),
  ('Northern Province',      'Kilinochchi'),
  ('Northern Province',      'Mannar'),
  ('Northern Province',      'Mullaitivu'),
  ('Northern Province',      'Vavuniya'),
  ('Sabaragamuwa Province',  'Kegalle'),
  ('Sabaragamuwa Province',  'Ratnapura'),
  ('Southern Province',      'Galle'),
  ('Southern Province',      'Hambantota'),
  ('Southern Province',      'Matara'),
  ('Uva Province',           'Badulla'),
  ('Uva Province',           'Monaragala'),
  ('Western Province',       'Colombo'),
  ('Western Province',       'Gampaha'),
  ('Western Province',       'Kalutara')
) as r(province, district);

alter table public.delivery_regions enable row level security;

create policy "delivery_regions read" on public.delivery_regions
  for select to authenticated using (true);

revoke all on public.delivery_regions from anon, authenticated;
grant select on public.delivery_regions to authenticated;

-- ----------------------------------------------------------------------------
-- 2. The address book
-- ----------------------------------------------------------------------------
-- Nullable because existing rows have no values for them. The trigger below makes
-- them required on every new or edited address.
alter table public.addresses
  add column recipient_name        text,
  add column province              text,
  add column landmark              text,
  add column delivery_instructions text,
  add column country_code          text not null default 'LK';

create index addresses_profile_idx
  on public.addresses (profile_id, is_default desc, updated_at desc);

create or replace function private.addresses_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.label                 := nullif(btrim(new.label), '');
  new.recipient_name        := nullif(btrim(new.recipient_name), '');
  new.phone                 := nullif(btrim(new.phone), '');
  new.country_code          := upper(btrim(new.country_code));
  new.province              := nullif(btrim(new.province), '');
  new.district              := nullif(btrim(new.district), '');
  new.city                  := btrim(new.city);
  new.line1                 := btrim(new.line1);
  new.line2                 := nullif(btrim(new.line2), '');
  new.landmark              := nullif(btrim(new.landmark), '');
  new.postal_code           := nullif(btrim(new.postal_code), '');
  new.delivery_instructions := nullif(btrim(new.delivery_instructions), '');

  if new.recipient_name is null or length(new.recipient_name) > 100 then
    raise exception 'invalid_address: the recipient name is required, up to 100 characters' using errcode = '22023';
  end if;
  if new.line1 = '' or length(new.line1) > 200 then
    raise exception 'invalid_address: the street address is required, up to 200 characters' using errcode = '22023';
  end if;
  if new.city = '' or length(new.city) > 100 then
    raise exception 'invalid_address: the city or town is required, up to 100 characters' using errcode = '22023';
  end if;
  if length(new.label) > 30 then
    raise exception 'invalid_address: the label is limited to 30 characters' using errcode = '22023';
  end if;
  if length(new.line2) > 200 or length(new.landmark) > 200 then
    raise exception 'invalid_address: address details are limited to 200 characters' using errcode = '22023';
  end if;
  if length(new.delivery_instructions) > 500 then
    raise exception 'invalid_address: delivery instructions are limited to 500 characters' using errcode = '22023';
  end if;

  -- The same rule as parsePhone in src/lib/auth/phone.ts: strict E.164, and a
  -- Sri Lankan number always has nine digits after +94.
  if new.phone is null or new.phone !~ '^\+[1-9][0-9]{6,14}$'
     or (new.phone like '+94%' and new.phone !~ '^\+94[0-9]{9}$') then
    raise exception 'invalid_phone: enter a valid contact number' using errcode = '22023';
  end if;

  if not exists (select 1 from public.delivery_regions r where r.country_code = new.country_code) then
    raise exception 'invalid_region: delivery is not available to that country' using errcode = '22023';
  end if;
  if not exists (select 1 from public.delivery_regions r
                  where r.country_code = new.country_code
                    and r.province = new.province
                    and r.district = new.district) then
    raise exception 'invalid_region: that district is not in that province' using errcode = '22023';
  end if;

  if new.country_code = 'LK' and new.postal_code is not null and new.postal_code !~ '^[0-9]{5}$' then
    raise exception 'invalid_postal_code: a Sri Lankan postal code has five digits' using errcode = '22023';
  end if;
  if length(new.postal_code) > 12 then
    raise exception 'invalid_postal_code: the postal code is limited to 12 characters' using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function private.addresses_validate() from public, anon, authenticated;

-- A change of is_default alone does not fire this, so an old incomplete row can
-- still be moved out of the way when another address becomes the default.
create trigger addresses_validate
  before insert or update of label, recipient_name, phone, country_code, province, district,
                             city, line1, line2, landmark, postal_code, delivery_instructions
  on public.addresses
  for each row execute function private.addresses_validate();

-- ----------------------------------------------------------------------------
-- 3. Address RLS
-- ----------------------------------------------------------------------------
-- "addresses own all" already gives customers exactly their own rows. See the
-- header for why the staff policy goes.
drop policy "addresses staff read" on public.addresses;

revoke all on public.addresses from anon;

-- ----------------------------------------------------------------------------
-- 4. Address book operations
-- ----------------------------------------------------------------------------
-- The customer always comes from auth.uid(). No function here takes a customer id.
create or replace function public.save_address(
  p_id                    uuid,
  p_label                 text,
  p_recipient_name        text,
  p_phone                 text,
  p_province              text,
  p_district              text,
  p_city                  text,
  p_line1                 text,
  p_line2                 text,
  p_landmark              text,
  p_postal_code           text,
  p_delivery_instructions text,
  p_make_default          boolean,
  p_country_code          text default 'LK'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_default boolean := coalesce(p_make_default, false);
  v_id      uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to save an address' using errcode = '42501';
  end if;

  -- One address book change at a time per customer.
  perform 1 from public.profiles where id = v_uid for no key update;

  if p_id is not null
     and not exists (select 1 from public.addresses where id = p_id and profile_id = v_uid) then
    raise exception 'address_not_found: that address is not in your account' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.addresses a
     where a.profile_id = v_uid
       and (p_id is null or a.id <> p_id)
       and lower(coalesce(a.recipient_name, '')) = lower(coalesce(btrim(p_recipient_name), ''))
       and coalesce(a.phone, '') = coalesce(btrim(p_phone), '')
       and a.country_code = upper(coalesce(btrim(p_country_code), ''))
       and coalesce(a.province, '') = coalesce(btrim(p_province), '')
       and coalesce(a.district, '') = coalesce(btrim(p_district), '')
       and lower(a.city) = lower(coalesce(btrim(p_city), ''))
       and lower(a.line1) = lower(coalesce(btrim(p_line1), ''))
       and lower(coalesce(a.line2, '')) = lower(coalesce(btrim(p_line2), ''))
  ) then
    raise exception 'address_duplicate: this address is already saved' using errcode = 'P0001';
  end if;

  -- A customer's first address is their default.
  if not exists (select 1 from public.addresses
                  where profile_id = v_uid and is_default and (p_id is null or id <> p_id)) then
    v_default := true;
  end if;

  -- Cleared first: the partial unique index is not deferrable.
  if v_default then
    update public.addresses set is_default = false
     where profile_id = v_uid and is_default and (p_id is null or id <> p_id);
  end if;

  if p_id is null then
    insert into public.addresses (profile_id, label, recipient_name, phone, country_code, province, district,
                                  city, line1, line2, landmark, postal_code, delivery_instructions, is_default)
    values (v_uid, p_label, p_recipient_name, p_phone, coalesce(p_country_code, ''), p_province, p_district,
            coalesce(p_city, ''), coalesce(p_line1, ''), p_line2, p_landmark, p_postal_code, p_delivery_instructions, v_default)
    returning id into v_id;
  else
    update public.addresses
       set label = p_label, recipient_name = p_recipient_name, phone = p_phone,
           country_code = coalesce(p_country_code, ''), province = p_province, district = p_district,
           city = coalesce(p_city, ''), line1 = coalesce(p_line1, ''), line2 = p_line2, landmark = p_landmark,
           postal_code = p_postal_code, delivery_instructions = p_delivery_instructions,
           is_default = is_default or v_default
     where id = p_id and profile_id = v_uid
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

create or replace function public.set_default_address(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to change your address' using errcode = '42501';
  end if;

  perform 1 from public.profiles where id = v_uid for no key update;

  if not exists (select 1 from public.addresses where id = p_id and profile_id = v_uid) then
    raise exception 'address_not_found: that address is not in your account' using errcode = 'P0001';
  end if;

  update public.addresses set is_default = false where profile_id = v_uid and is_default and id <> p_id;
  update public.addresses set is_default = true where id = p_id and profile_id = v_uid;
end;
$$;

-- Removing the default hands the role to the most recently changed address, so a
-- customer with addresses always has a default. Orders hold their own copy, so
-- this cannot touch history.
create or replace function public.delete_address(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_default boolean;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to change your address' using errcode = '42501';
  end if;

  perform 1 from public.profiles where id = v_uid for no key update;

  delete from public.addresses where id = p_id and profile_id = v_uid returning is_default into v_default;
  if not found then
    raise exception 'address_not_found: that address is not in your account' using errcode = 'P0001';
  end if;

  if v_default then
    update public.addresses set is_default = true
     where id = (select id from public.addresses
                  where profile_id = v_uid
                  order by updated_at desc, id
                  limit 1);
  end if;
end;
$$;

revoke all on function public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text) from public, anon, service_role;
revoke all on function public.set_default_address(uuid) from public, anon, service_role;
revoke all on function public.delete_address(uuid) from public, anon, service_role;
grant execute on function public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text) to authenticated;
grant execute on function public.set_default_address(uuid) to authenticated;
grant execute on function public.delete_address(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 5. The order snapshot
-- ----------------------------------------------------------------------------
create or replace function private.address_snapshot(p_address public.addresses)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_country text;
begin
  select r.country_name into v_country from public.delivery_regions r
   where r.country_code = p_address.country_code
     and r.province = p_address.province
     and r.district = p_address.district;

  -- Also catches an old row that was saved before these fields existed.
  if v_country is null or p_address.recipient_name is null or p_address.phone is null then
    raise exception 'address_incomplete: this address needs its details completed' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'label',                 coalesce(p_address.label, ''),
    'recipient_name',        p_address.recipient_name,
    'contact_number',        p_address.phone,
    'country_code',          p_address.country_code,
    'country',               v_country,
    'province',              p_address.province,
    'district',              p_address.district,
    'city',                  p_address.city,
    'address_line_1',        p_address.line1,
    'address_line_2',        coalesce(p_address.line2, ''),
    'landmark',              coalesce(p_address.landmark, ''),
    'postal_code',           coalesce(p_address.postal_code, ''),
    'delivery_instructions', coalesce(p_address.delivery_instructions, '')
  );
end;
$$;

revoke all on function private.address_snapshot(public.addresses) from public, anon, authenticated, service_role;

-- Pricing, stock and warranty stay in place_order_impl, untouched. Both statements
-- run in this function's transaction, so an order can never exist without its
-- snapshot.
create or replace function public.place_order_v3(
  p_lines      jsonb,
  p_address_id uuid,
  p_notes      text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_address  public.addresses;
  v_snapshot jsonb;
  v_result   jsonb;
  v_order_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to place an order' using errcode = '42501';
  end if;
  if p_address_id is null then
    raise exception 'address_required: choose a delivery address' using errcode = 'P0001';
  end if;

  select * into v_address from public.addresses where id = p_address_id and profile_id = v_uid;
  if not found then
    raise exception 'address_not_found: that address is not in your account' using errcode = 'P0001';
  end if;

  v_snapshot := private.address_snapshot(v_address);
  v_result   := private.place_order_impl(p_lines, p_notes, p_request_id);
  v_order_id := (v_result ->> 'id')::uuid;

  if (v_result ->> 'replayed')::boolean then
    -- A retry returns the first order only if it is the same delivery. The
    -- fingerprint covers lines and notes; this covers the address, so changing
    -- the address after a lost response is refused instead of silently keeping
    -- the old one or ordering twice.
    if exists (select 1 from public.orders
                where id = v_order_id and shipping_address is distinct from v_snapshot) then
      raise exception 'request_id_reused: this request id was already used with a different address' using errcode = 'P0001';
    end if;
    return v_result;
  end if;

  update public.orders set shipping_address = v_snapshot where id = v_order_id;

  return v_result;
end;
$$;

comment on function public.place_order_v3(jsonb, uuid, text, uuid) is
  'Customer order placement with a required delivery address owned by the caller. The client never supplies an amount.';

revoke all on function public.place_order_v3(jsonb, uuid, text, uuid) from public, anon, service_role;
grant execute on function public.place_order_v3(jsonb, uuid, text, uuid) to authenticated;

-- The old entry points keep their signatures, so installed apps get this sentence
-- rather than a missing-function error.
create or replace function public.place_order_v2(
  p_lines      jsonb,
  p_notes      text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'address_required: please update the app to choose a delivery address' using errcode = 'P0001';
end;
$$;

create or replace function public.place_order(
  p_lines jsonb,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'address_required: please update the app to choose a delivery address' using errcode = 'P0001';
end;
$$;

comment on function public.place_order_v2(jsonb, text, uuid) is
  'Retired: refuses every call, because it cannot carry a delivery address. See place_order_v3.';
comment on function public.place_order(jsonb, text) is
  'Retired: refuses every call, because it cannot carry a delivery address. See place_order_v3.';

-- ----------------------------------------------------------------------------
-- 6. A snapshot cannot change
-- ----------------------------------------------------------------------------
-- Clients already cannot write this column: authenticated holds UPDATE on status
-- only. This holds for everything else, including the service role. The one
-- permitted write is the first one, from NULL, which place_order_v3 makes.
create or replace function private.orders_protect_shipping_address()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.shipping_address is not null and new.shipping_address is distinct from old.shipping_address then
    raise exception 'order_address_immutable: the delivery address of a placed order cannot change'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.orders_protect_shipping_address() from public, anon, authenticated;

create trigger orders_protect_shipping_address
  before update of shipping_address on public.orders
  for each row execute function private.orders_protect_shipping_address();

comment on column public.orders.shipping_address is
  'Delivery address copied at placement by place_order_v3. Never joined to public.addresses, and cannot change once written.';

-- ----------------------------------------------------------------------------
-- 7. Internal delivery notes
-- ----------------------------------------------------------------------------
-- Append-only, like order_events. No customer policy exists, so a customer reads
-- nothing here, even for their own order.
create table public.order_delivery_notes (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null references public.orders (id) on delete cascade,
  note       text not null check (length(btrim(note)) between 1 and 1000),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index order_delivery_notes_order_idx on public.order_delivery_notes (order_id, created_at desc);

comment on table public.order_delivery_notes is
  'Staff-only delivery notes on an order. Never visible to customers.';

alter table public.order_delivery_notes enable row level security;

create policy "order_delivery_notes staff read" on public.order_delivery_notes
  for select to authenticated using (private.has_role('staff'));
create policy "order_delivery_notes staff insert" on public.order_delivery_notes
  for insert to authenticated
  with check (private.has_role('staff') and created_by = (select auth.uid()));

revoke all on public.order_delivery_notes from anon, authenticated;
grant select, insert on public.order_delivery_notes to authenticated;

-- ----------------------------------------------------------------------------
-- 8. The account's verified phone, for the order screen
-- ----------------------------------------------------------------------------
-- A phone sign-in leaves profiles.phone empty, and the number it verified is in
-- auth.users, which clients cannot read. Staff get that one value, for the customer
-- of one order, so the account's contact can be told apart from the recipient's.
create or replace function public.admin_order_account_phone(p_order_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_phone text;
begin
  if not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;

  select u.phone into v_phone
    from public.orders o
    join auth.users u on u.id = o.profile_id
   where o.id = p_order_id and u.phone_confirmed_at is not null;

  -- Supabase Auth stores numbers without the leading '+'.
  return case when nullif(v_phone, '') is null then null else '+' || ltrim(v_phone, '+') end;
end;
$$;

revoke all on function public.admin_order_account_phone(uuid) from public, anon, service_role;
grant execute on function public.admin_order_account_phone(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 9. Verification
-- ----------------------------------------------------------------------------
do $$
begin
  if (select count(*) from public.delivery_regions where country_code = 'LK') <> 25
     or (select count(distinct province) from public.delivery_regions where country_code = 'LK') <> 9 then
    raise exception 'delivery_regions must hold 25 districts in 9 provinces';
  end if;
  if has_function_privilege('anon', 'public.place_order_v3(jsonb, uuid, text, uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.place_order_v3(jsonb, uuid, text, uuid)', 'EXECUTE') then
    raise exception 'address function privileges are wrong';
  end if;
  if has_column_privilege('authenticated', 'public.orders', 'shipping_address', 'UPDATE') then
    raise exception 'authenticated must not be able to write orders.shipping_address';
  end if;
  raise notice 'verified: address book, delivery regions and order snapshot';
end;
$$;

-- Rollback (manual, if ever needed). Saved addresses and snapshots are customer
-- data, so keep the columns. Restore the old entry points from 20261101100000
-- and the staff policy from the header, then:
--   drop function public.place_order_v3(jsonb, uuid, text, uuid);
--   drop function public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text);
--   drop function public.set_default_address(uuid);
--   drop function public.delete_address(uuid);
--   drop function public.admin_order_account_phone(uuid);
--   drop trigger orders_protect_shipping_address on public.orders;
--   drop trigger addresses_validate on public.addresses;
--   drop table public.order_delivery_notes;
