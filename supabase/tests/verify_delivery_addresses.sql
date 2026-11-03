-- ============================================================================
-- Apple Expert - saved delivery addresses and the order address snapshot
-- ----------------------------------------------------------------------------
-- Run as postgres against the LOCAL stack:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_delivery_addresses.sql
--
-- Every check RAISES on failure. Fixtures live in one transaction that is rolled
-- back, and role impersonation sets the claims PostgREST would set. A clean run
-- ends with "ALL DELIVERY ADDRESS CHECKS PASSED".
-- ============================================================================

\set ON_ERROR_STOP on

begin;

create function pg_temp.as_user(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.as_anon() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end $$;

create function pg_temp.as_postgres() returns void language sql as $$
  select set_config('role', 'postgres', true); select set_config('request.jwt.claims', '', true);
$$;

create function pg_temp.expect_fail(p_label text, p_sql text, p_like text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm like p_like then return; end if;
    raise exception '% FAILED - wrong error: % (sqlstate %)', p_label, sqlerrm, sqlstate;
  end;
  raise exception '% FAILED - statement succeeded: %', p_label, p_sql;
end $$;

-- A valid address, with named overrides where a check needs a bad value.
create function pg_temp.save(
  p_id uuid default null, p_label text default 'Home', p_name text default 'Test Recipient',
  p_phone text default '+94771234567', p_province text default 'Eastern Province',
  p_district text default 'Trincomalee', p_city text default 'Kinniya',
  p_line1 text default 'No. 25, Main Street', p_line2 text default null, p_landmark text default null,
  p_postal text default null, p_instructions text default null, p_default boolean default false,
  p_country text default 'LK'
) returns uuid language sql as $$
  select public.save_address(p_id, p_label, p_name, p_phone, p_province, p_district, p_city, p_line1, p_line2,
                             p_landmark, p_postal, p_instructions, p_default, p_country)
$$;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '',
       now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false
from (values
  ('da111111-1111-1111-1111-111111111111', 'da-retail@test.local'),
  ('da222222-2222-2222-2222-222222222222', 'da-vip@test.local'),
  ('da333333-3333-3333-3333-333333333333', 'da-other@test.local'),
  ('da444444-4444-4444-4444-444444444444', 'da-staff@test.local'),
  ('da555555-5555-5555-5555-555555555555', 'da-admin@test.local'),
  ('da666666-6666-6666-6666-666666666666', 'da-owner@test.local')
) as u(id, email);

update public.profiles set customer_type = 'wholesale_vip', vip_approved_at = now() - interval '1 day'
 where id = 'da222222-2222-2222-2222-222222222222';

insert into public.user_roles (profile_id, role) values
  ('da444444-4444-4444-4444-444444444444', 'staff'),
  ('da555555-5555-5555-5555-555555555555', 'admin'),
  ('da666666-6666-6666-6666-666666666666', 'owner');

insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode)
values ('da-item', 'Address test item', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 50, true, 'quantity'),
       ('da-rare', 'Address test last unit', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 1, true, 'quantity');

insert into public.product_prices (product_id, tier_code, price_cents, min_qty, starts_at) values
  ('da-item', 'retail', 200000, 1, now() - interval '1 day'),
  ('da-item', 'wholesale_vip', 150000, 1, now() - interval '1 day'),
  ('da-rare', 'retail', 100000, 1, now() - interval '1 day');

do $$
declare
  c_retail constant uuid := 'da111111-1111-1111-1111-111111111111';
  c_vip    constant uuid := 'da222222-2222-2222-2222-222222222222';
  c_other  constant uuid := 'da333333-3333-3333-3333-333333333333';
  c_staff  constant uuid := 'da444444-4444-4444-4444-444444444444';
  c_admin  constant uuid := 'da555555-5555-5555-5555-555555555555';
  c_owner  constant uuid := 'da666666-6666-6666-6666-666666666666';
  c_lines  constant jsonb := '[{"product_id":"da-item","quantity":2}]';
  v_home   uuid;
  v_work   uuid;
  v_vip    uuid;
  v_other  uuid;
  v_n      bigint;
  v_res    jsonb;
  v_order  uuid;
  v_vip_order uuid;
  v_snap   jsonb;
  v_req    uuid;
begin
  -- A1 reference data ---------------------------------------------------------
  perform pg_temp.as_user(c_retail);
  select count(*) into v_n from public.delivery_regions;
  if v_n <> 25 then raise exception 'A1 FAILED - customer read % districts', v_n; end if;
  perform pg_temp.expect_fail('A1 customer writes a region',
    $q$insert into public.delivery_regions values ('LK','Sri Lanka','Fake Province','Fake')$q$, 'permission denied%');
  perform pg_temp.as_anon();
  perform pg_temp.expect_fail('A1 anon reads regions', $q$select * from public.delivery_regions$q$, 'permission denied%');
  raise notice 'A1 ok - 25 districts readable by customers, writable by no client, hidden from anon';

  -- A2 add, multiple, default -------------------------------------------------
  perform pg_temp.as_user(c_retail);
  v_home := pg_temp.save(p_landmark := 'Near Main Junction', p_instructions := 'Please call before delivery');
  if not (select is_default from public.addresses where id = v_home) then
    raise exception 'A2 FAILED - the first address is not the default';
  end if;
  v_work := pg_temp.save(p_label := 'Work', p_province := 'Western Province', p_district := 'Colombo',
                         p_city := 'Colombo 03', p_line1 := '1 Galle Road');
  select count(*) into v_n from public.addresses;
  if v_n <> 2 or (select is_default from public.addresses where id = v_work) then
    raise exception 'A2 FAILED - second address count % or took the default', v_n;
  end if;
  raise notice 'A2 ok - add, multiple addresses, first becomes default';

  -- A3 set default is atomic and single --------------------------------------
  perform public.set_default_address(v_work);
  if (select count(*) from public.addresses where is_default) <> 1
     or not (select is_default from public.addresses where id = v_work) then
    raise exception 'A3 FAILED - default did not move cleanly';
  end if;
  perform pg_temp.expect_fail('A3 customer writes a default directly',
    format('update public.addresses set is_default = true where id = %L', v_home), 'permission denied%');
  -- Below the grants, the index still refuses a second default.
  perform pg_temp.as_postgres();
  perform pg_temp.expect_fail('A3 two defaults written directly',
    format('update public.addresses set is_default = true where id = %L', v_home), 'duplicate key%');
  perform pg_temp.as_user(c_retail);
  perform public.set_default_address(v_home);
  raise notice 'A3 ok - exactly one default, and the index refuses a second';

  -- A4 edit --------------------------------------------------------------------
  perform pg_temp.save(p_id := v_work, p_label := 'Office', p_province := 'Western Province', p_district := 'Colombo',
                       p_city := 'Colombo 04', p_line1 := '1 Galle Road');
  if (select city from public.addresses where id = v_work) <> 'Colombo 04'
     or (select label from public.addresses where id = v_work) <> 'Office'
     or (select is_default from public.addresses where id = v_work) then
    raise exception 'A4 FAILED - edit did not apply, or changed the default';
  end if;
  -- Saving the default address again must not drop the customer's default.
  perform pg_temp.save(p_id := v_home, p_landmark := 'Near Main Junction', p_instructions := 'Please call before delivery');
  if not (select is_default from public.addresses where id = v_home) then
    raise exception 'A4 FAILED - editing the default lost it';
  end if;
  raise notice 'A4 ok - edit applies and leaves the default alone';

  -- A5 validation -------------------------------------------------------------
  perform pg_temp.expect_fail('A5 phone letters', $q$select pg_temp.save(p_phone := 'not-a-phone', p_line1 := 'x')$q$, 'invalid_phone:%');
  perform pg_temp.expect_fail('A5 phone local form', $q$select pg_temp.save(p_phone := '0771234567', p_line1 := 'x')$q$, 'invalid_phone:%');
  perform pg_temp.expect_fail('A5 phone short LK', $q$select pg_temp.save(p_phone := '+9477123', p_line1 := 'x')$q$, 'invalid_phone:%');
  perform pg_temp.expect_fail('A5 phone missing', $q$select pg_temp.save(p_phone := null, p_line1 := 'x')$q$, 'invalid_phone:%');
  perform pg_temp.expect_fail('A5 name missing', $q$select pg_temp.save(p_name := '   ', p_line1 := 'x')$q$, 'invalid_address:%');
  perform pg_temp.expect_fail('A5 street missing', $q$select pg_temp.save(p_line1 := '')$q$, 'invalid_address:%');
  perform pg_temp.expect_fail('A5 street null', $q$select pg_temp.save(p_line1 := null)$q$, 'invalid_address:%');
  perform pg_temp.expect_fail('A5 city missing', $q$select pg_temp.save(p_city := ' ', p_line1 := 'x')$q$, 'invalid_address:%');
  perform pg_temp.expect_fail('A5 province missing', $q$select pg_temp.save(p_province := null, p_line1 := 'x')$q$, 'invalid_region:%');
  perform pg_temp.expect_fail('A5 mismatch', $q$select pg_temp.save(p_province := 'Western Province', p_district := 'Trincomalee', p_line1 := 'x')$q$, 'invalid_region:%');
  perform pg_temp.expect_fail('A5 country', $q$select pg_temp.save(p_country := 'US', p_province := 'CA', p_district := 'LA', p_line1 := 'x')$q$, 'invalid_region:%');
  perform pg_temp.expect_fail('A5 postal', $q$select pg_temp.save(p_postal := 'ABC', p_line1 := 'x')$q$, 'invalid_postal_code:%');
  -- A customer cannot write the table directly at all (see P1). The trigger still
  -- holds for every other writer, such as a server task or a migration.
  perform pg_temp.as_postgres();
  perform pg_temp.expect_fail('A5 direct insert bypass',
    format($q$insert into public.addresses (profile_id, line1, city, recipient_name, phone, province, district)
              values (%L, 'x', 'x', 'x', '+94771234567', 'Western Province', 'Trincomalee')$q$, c_retail), 'invalid_region:%');
  perform pg_temp.as_user(c_retail);
  -- A failed save changes nothing, including the default it would have moved.
  perform pg_temp.expect_fail('A5 default move rolled back', $q$select pg_temp.save(p_phone := 'bad', p_line1 := 'x', p_default := true)$q$, 'invalid_phone:%');
  if not (select is_default from public.addresses where id = v_home) then
    raise exception 'A5 FAILED - a refused save moved the default';
  end if;
  raise notice 'A5 ok - phone, required fields, province/district, country and postal code enforced in the database';

  -- A6 no needless duplicates -------------------------------------------------
  perform pg_temp.expect_fail('A6 same address', $q$select pg_temp.save(p_label := 'Again', p_line1 := ' no. 25, main street ')$q$, 'address_duplicate:%');
  perform pg_temp.expect_fail('A6 edit into a duplicate',
    format($q$select pg_temp.save(p_id := %L)$q$, v_work), 'address_duplicate:%');
  raise notice 'A6 ok - an identical address is refused, whitespace and case ignored';

  -- S1 customers are isolated -------------------------------------------------
  perform pg_temp.as_user(c_vip);
  v_vip := pg_temp.save(p_name := 'VIP Recipient', p_line1 := '9 Trade Lane');
  perform pg_temp.as_user(c_other);
  v_other := pg_temp.save(p_name := 'Other Person', p_line1 := '7 Lake Road');

  foreach v_req in array array[c_retail, c_vip] loop
    perform pg_temp.as_user(v_req);
    select count(*) into v_n from public.addresses where profile_id <> v_req;
    if v_n <> 0 then raise exception 'S1 FAILED - % read % other addresses', v_req, v_n; end if;
    perform pg_temp.expect_fail('S1 update another', format($q$update public.addresses set city = 'Hacked' where id = %L$q$, v_other), 'permission denied%');
    perform pg_temp.expect_fail('S1 delete another', format($q$delete from public.addresses where id = %L$q$, v_other), 'permission denied%');
    perform pg_temp.expect_fail('S1 insert for another',
      format($q$insert into public.addresses (profile_id, line1, city, recipient_name, phone, province, district)
                values (%L, 'y', 'y', 'y', '+94771234567', 'Western Province', 'Colombo')$q$, c_other), 'permission denied%');
    perform pg_temp.expect_fail('S1 save another', format($q$select pg_temp.save(p_id := %L)$q$, v_other), 'address_not_found:%');
    perform pg_temp.expect_fail('S1 default another', format($q$select public.set_default_address(%L)$q$, v_other), 'address_not_found:%');
    perform pg_temp.expect_fail('S1 delete another', format($q$select public.delete_address(%L)$q$, v_other), 'address_not_found:%');
  end loop;
  perform pg_temp.as_user(c_retail);
  perform pg_temp.expect_fail('S1 steal a row',
    format($q$update public.addresses set profile_id = %L where id = %L$q$, c_other, v_home), 'permission denied%');
  perform pg_temp.as_postgres();
  if (select city from public.addresses where id = v_other) <> 'Kinniya' then
    raise exception 'S1 FAILED - another customer''s address changed';
  end if;

  perform pg_temp.as_anon();
  perform pg_temp.expect_fail('S1 anon reads', $q$select * from public.addresses$q$, 'permission denied%');
  perform pg_temp.expect_fail('S1 anon saves', $q$select pg_temp.save()$q$, 'permission denied%');
  perform pg_temp.expect_fail('S1 anon sets default', format($q$select public.set_default_address(%L)$q$, v_other), 'permission denied%');
  perform pg_temp.expect_fail('S1 anon deletes', format($q$select public.delete_address(%L)$q$, v_other), 'permission denied%');
  raise notice 'S1 ok - retail and VIP customers cannot read, change, delete or claim another customer''s address';

  -- P1 a customer writes their own address book only through the functions ------
  foreach v_req in array array[c_retail, c_vip] loop
    perform pg_temp.as_user(v_req);
    select count(*) into v_n from public.addresses;
    perform pg_temp.expect_fail('P1 direct insert own',
      format($q$insert into public.addresses (profile_id, line1, city, recipient_name, phone, province, district)
                values (%L, '8 Direct Lane', 'Galle', 'Direct', '+94771234567', 'Southern Province', 'Galle')$q$, v_req), 'permission denied%');
    perform pg_temp.expect_fail('P1 direct update own', $q$update public.addresses set city = 'Direct'$q$, 'permission denied%');
    perform pg_temp.expect_fail('P1 direct default own', $q$update public.addresses set is_default = false$q$, 'permission denied%');
    perform pg_temp.expect_fail('P1 direct delete own', $q$delete from public.addresses$q$, 'permission denied%');
    if (select count(*) from public.addresses) <> v_n
       or exists (select 1 from public.addresses where city = 'Direct') then
      raise exception 'P1 FAILED - a direct write by % changed the address book', v_req;
    end if;
  end loop;
  perform pg_temp.as_postgres();
  if exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'addresses' and cmd <> 'SELECT')
     or exists (select 1 from pg_proc p
                 where p.oid in ('public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text)'::regprocedure,
                                 'public.set_default_address(uuid)'::regprocedure, 'public.delete_address(uuid)'::regprocedure)
                   and not p.prosecdef) then
    raise exception 'P1 FAILED - a write policy remains, or an address function is not SECURITY DEFINER';
  end if;
  raise notice 'P1 ok - retail and VIP direct insert, update and delete are refused; the table has only a read policy';

  -- V1 a VIP customer manages their own address book through the functions -----
  perform pg_temp.as_user(c_vip);
  v_req := pg_temp.save(p_name := 'VIP Second', p_label := 'Work', p_line1 := '10 Trade Lane');
  perform pg_temp.save(p_id := v_req, p_name := 'VIP Second', p_label := 'Work', p_line1 := '11 Trade Lane');
  perform public.set_default_address(v_req);
  if (select count(*) from public.addresses) <> 2
     or not (select is_default from public.addresses where id = v_req)
     or (select line1 from public.addresses where id = v_req) <> '11 Trade Lane' then
    raise exception 'V1 FAILED - VIP add, edit or set default did not apply';
  end if;
  perform public.delete_address(v_req);
  if (select count(*) from public.addresses) <> 1 or not (select is_default from public.addresses where id = v_vip) then
    raise exception 'V1 FAILED - VIP delete did not hand the default back';
  end if;
  raise notice 'V1 ok - a VIP customer adds, edits, sets default and deletes their own addresses';

  -- S2 staff do not get the address book ---------------------------------------
  foreach v_req in array array[c_staff, c_admin, c_owner] loop
    perform pg_temp.as_user(v_req);
    select count(*) into v_n from public.addresses;
    if v_n <> 0 then raise exception 'S2 FAILED - role % read % saved addresses', v_req, v_n; end if;
  end loop;
  raise notice 'S2 ok - staff, admin and owner see delivery details through orders, not the address book';

  -- C1 retail checkout with an existing address, and the exact snapshot --------
  perform pg_temp.as_user(c_retail);
  perform pg_temp.save(p_id := v_home, p_line2 := 'Second floor', p_landmark := 'Near Main Junction', p_postal := '31100',
                       p_instructions := 'Please call before delivery');
  v_res := public.place_order_v3(c_lines, v_home, null, gen_random_uuid());
  v_order := (v_res ->> 'id')::uuid;
  select shipping_address into v_snap from public.orders where id = v_order;
  if v_snap <> jsonb_build_object(
       'label', 'Home', 'recipient_name', 'Test Recipient', 'contact_number', '+94771234567',
       'country_code', 'LK', 'country', 'Sri Lanka', 'province', 'Eastern Province', 'district', 'Trincomalee',
       'city', 'Kinniya', 'address_line_1', 'No. 25, Main Street', 'address_line_2', 'Second floor',
       'landmark', 'Near Main Junction', 'postal_code', '31100', 'delivery_instructions', 'Please call before delivery') then
    raise exception 'C1 FAILED - wrong snapshot: %', v_snap;
  end if;
  -- Pricing stays where it was: database resolved, retail tier, 2 x Rs. 2,000.
  if (v_res ->> 'total_cents')::bigint <> 400000
     or (select customer_type_at_purchase from public.orders where id = v_order) <> 'retail' then
    raise exception 'C1 FAILED - retail total wrong: %', v_res;
  end if;
  raise notice 'C1 ok - retail order carries the full snapshot and the database price';

  -- C2 VIP checkout with a newly created address ------------------------------
  perform pg_temp.as_user(c_vip);
  v_vip := pg_temp.save(p_name := 'VIP Branch', p_province := 'Central Province', p_district := 'Kandy',
                        p_city := 'Kandy', p_line1 := '3 Hill Street');
  v_res := public.place_order_v3(c_lines, v_vip, null, gen_random_uuid());
  v_vip_order := (v_res ->> 'id')::uuid;
  if (v_res ->> 'total_cents')::bigint <> 300000
     or (select customer_type_at_purchase from public.orders where id = v_vip_order) <> 'wholesale_vip'
     or (select shipping_address ->> 'recipient_name' from public.orders where id = v_vip_order) <> 'VIP Branch' then
    raise exception 'C2 FAILED - VIP order wrong: %', v_res;
  end if;
  raise notice 'C2 ok - VIP order with a just-created address, VIP price kept';

  -- C3 no address, someone else's, unusable ------------------------------------
  perform pg_temp.as_user(c_retail);
  select count(*) into v_n from public.orders;
  perform pg_temp.expect_fail('C3 no address', format($q$select public.place_order_v3(%L, null, null, gen_random_uuid())$q$, c_lines), 'address_required:%');
  perform pg_temp.expect_fail('C3 other customer''s', format($q$select public.place_order_v3(%L, %L, null, gen_random_uuid())$q$, c_lines, v_other), 'address_not_found:%');
  perform pg_temp.expect_fail('C3 unknown id', format($q$select public.place_order_v3(%L, gen_random_uuid(), null, gen_random_uuid())$q$, c_lines), 'address_not_found:%');
  perform pg_temp.expect_fail('C3 retired place_order', format($q$select public.place_order(%L)$q$, c_lines), 'address_required:%');
  perform pg_temp.expect_fail('C3 retired v2', format($q$select public.place_order_v2(%L, null, gen_random_uuid())$q$, c_lines), 'address_required:%');
  perform pg_temp.expect_fail('C3 tampered client total',
    format($q$select public.place_order_v3(%L, %L, null, gen_random_uuid(), 1)$q$, c_lines, v_home), '%does not exist%');

  perform pg_temp.as_postgres();
  insert into public.addresses (id, profile_id, line1, city, recipient_name, phone, province, district)
  values ('da777777-7777-7777-7777-777777777777', c_retail, '5 Old Row', 'Galle', 'Old', '+94771234567', 'Southern Province', 'Galle');
  alter table public.addresses disable trigger addresses_validate;
  update public.addresses set recipient_name = null, province = null where id = 'da777777-7777-7777-7777-777777777777';
  alter table public.addresses enable trigger addresses_validate;
  perform pg_temp.as_user(c_retail);
  perform pg_temp.expect_fail('C3 pre-existing incomplete row',
    format($q$select public.place_order_v3(%L, 'da777777-7777-7777-7777-777777777777', null, gen_random_uuid())$q$, c_lines), 'address_incomplete:%');
  -- It can still be moved past when another address becomes the default.
  perform public.set_default_address('da777777-7777-7777-7777-777777777777');
  perform public.set_default_address(v_home);
  perform pg_temp.as_postgres();
  delete from public.addresses where id = 'da777777-7777-7777-7777-777777777777';

  perform pg_temp.as_user(c_retail);
  if (select count(*) from public.orders) <> v_n then
    raise exception 'C3 FAILED - a refused call created an order';
  end if;
  raise notice 'C3 ok - no address, another customer''s, an incomplete row and the retired entry points all refused';

  -- C4 the order and its snapshot are one transaction ---------------------------
  select count(*) into v_n from public.orders;
  perform pg_temp.expect_fail('C4 stock failure',
    format($q$select public.place_order_v3('[{"product_id":"da-item","quantity":1},{"product_id":"da-rare","quantity":5}]', %L, null, gen_random_uuid())$q$, v_home),
    'insufficient_stock:%');
  if (select count(*) from public.orders) <> v_n then
    raise exception 'C4 FAILED - a failed order left a row behind';
  end if;
  raise notice 'C4 ok - an order that fails leaves nothing';

  -- C5 address changed before placing, and on a retry ---------------------------
  v_req := gen_random_uuid();
  v_res := public.place_order_v3(c_lines, v_work, null, v_req);
  if (select shipping_address ->> 'city' from public.orders where id = (v_res ->> 'id')::uuid) <> 'Colombo 04' then
    raise exception 'C5 FAILED - the order did not use the address chosen last';
  end if;
  if (public.place_order_v3(c_lines, v_work, null, v_req) ->> 'replayed')::boolean is not true then
    raise exception 'C5 FAILED - a retry did not return the first order';
  end if;
  perform pg_temp.expect_fail('C5 retry with another address',
    format($q$select public.place_order_v3(%L, %L, null, %L)$q$, c_lines, v_home, v_req), 'request_id_reused:%');
  raise notice 'C5 ok - the chosen address is the one recorded; a retry never swaps it or orders twice';

  -- I1 nobody can rewrite a snapshot --------------------------------------------
  perform pg_temp.as_user(c_retail);
  perform pg_temp.expect_fail('I1 customer', format($q$update public.orders set shipping_address = '{"city":"x"}' where id = %L$q$, v_order), 'permission denied%');
  -- status is the one granted column, and RLS gives customers no row to change.
  update public.orders set status = 'cancelled' where id = v_order;
  if (select status from public.orders where id = v_order) <> 'pending' then
    raise exception 'I1 FAILED - a customer changed their order status';
  end if;
  foreach v_req in array array[c_staff, c_admin, c_owner] loop
    perform pg_temp.as_user(v_req);
    perform pg_temp.expect_fail('I1 ' || v_req, format($q$update public.orders set shipping_address = '{"city":"x"}' where id = %L$q$, v_order), 'permission denied%');
  end loop;
  perform pg_temp.as_postgres();
  perform pg_temp.expect_fail('I1 trigger', format($q$update public.orders set shipping_address = '{"city":"x"}' where id = %L$q$, v_order), 'order_address_immutable:%');
  perform pg_temp.expect_fail('I1 trigger null', format($q$update public.orders set shipping_address = null where id = %L$q$, v_order), 'order_address_immutable:%');
  -- A status change, which staff do all day, leaves it alone.
  perform pg_temp.as_user(c_staff);
  update public.orders set status = 'confirmed' where id = v_order;
  if (select shipping_address from public.orders where id = v_order) <> v_snap then
    raise exception 'I1 FAILED - a status change altered the snapshot';
  end if;
  raise notice 'I1 ok - customers, staff, admin, owner and postgres itself cannot rewrite a snapshot';

  -- H1 history survives editing and deleting the saved address -------------------
  perform pg_temp.as_user(c_retail);
  perform pg_temp.save(p_id := v_home, p_name := 'Someone Else', p_city := 'Mutur', p_line1 := '99 New Road');
  if (select shipping_address from public.orders where id = v_order) <> v_snap then
    raise exception 'H1 FAILED - editing a saved address changed an order';
  end if;
  perform public.delete_address(v_home);
  if (select shipping_address from public.orders where id = v_order) <> v_snap then
    raise exception 'H1 FAILED - deleting a saved address changed an order';
  end if;
  -- The default passed to the remaining address.
  if not (select is_default from public.addresses where id = v_work) then
    raise exception 'H1 FAILED - deleting the default left the customer without one';
  end if;
  raise notice 'H1 ok - edit and delete leave the order unchanged; the default moves on';

  -- R1 who can read a snapshot --------------------------------------------------
  foreach v_req in array array[c_staff, c_admin, c_owner] loop
    perform pg_temp.as_user(v_req);
    if (select shipping_address from public.orders where id = v_order) <> v_snap then
      raise exception 'R1 FAILED - role % cannot read the snapshot', v_req;
    end if;
  end loop;
  perform pg_temp.as_user(c_vip);
  if exists (select 1 from public.orders where id = v_order) then
    raise exception 'R1 FAILED - a customer read another customer''s order';
  end if;
  perform pg_temp.as_user(c_retail);
  if (select shipping_address from public.orders where id = v_order) <> v_snap then
    raise exception 'R1 FAILED - the customer cannot read their own snapshot';
  end if;
  raise notice 'R1 ok - staff roles and the owning customer read it; other customers do not';

  -- N1 internal notes -----------------------------------------------------------
  perform pg_temp.as_user(c_staff);
  insert into public.order_delivery_notes (order_id, note) values (v_order, 'Courier needs a call first');
  if (select created_by from public.order_delivery_notes where order_id = v_order) <> c_staff then
    raise exception 'N1 FAILED - author not recorded';
  end if;
  perform pg_temp.expect_fail('N1 forged author',
    format($q$insert into public.order_delivery_notes (order_id, note, created_by) values (%L, 'x', %L)$q$, v_order, c_admin), '%row-level security%');
  perform pg_temp.expect_fail('N1 blank', format($q$insert into public.order_delivery_notes (order_id, note) values (%L, '  ')$q$, v_order), '%check constraint%');
  perform pg_temp.expect_fail('N1 staff edits', format($q$update public.order_delivery_notes set note = 'x' where order_id = %L$q$, v_order), 'permission denied%');
  perform pg_temp.expect_fail('N1 staff deletes', format($q$delete from public.order_delivery_notes where order_id = %L$q$, v_order), 'permission denied%');

  perform pg_temp.as_user(c_admin);
  if (select count(*) from public.order_delivery_notes where order_id = v_order) <> 1 then
    raise exception 'N1 FAILED - admin cannot read the note';
  end if;

  perform pg_temp.as_user(c_retail);
  if (select count(*) from public.order_delivery_notes) <> 0 then
    raise exception 'N1 FAILED - the customer read an internal note on their own order';
  end if;
  perform pg_temp.expect_fail('N1 customer writes',
    format($q$insert into public.order_delivery_notes (order_id, note) values (%L, 'x')$q$, v_order), '%row-level security%');
  perform pg_temp.as_anon();
  perform pg_temp.expect_fail('N1 anon reads', $q$select * from public.order_delivery_notes$q$, 'permission denied%');
  raise notice 'N1 ok - notes are staff only and append only; the owning customer sees none';

  -- N2 the verified sign-in number -----------------------------------------------
  perform pg_temp.as_postgres();
  update auth.users set phone = '94770000111', phone_confirmed_at = now() where id = c_retail;
  perform pg_temp.as_user(c_staff);
  if public.admin_order_account_phone(v_order) <> '+94770000111' then
    raise exception 'N2 FAILED - staff did not get the verified number';
  end if;
  perform pg_temp.as_user(c_retail);
  perform pg_temp.expect_fail('N2 customer', format($q$select public.admin_order_account_phone(%L)$q$, v_order), 'insufficient_privilege:%');
  perform pg_temp.as_user(c_vip);
  perform pg_temp.expect_fail('N2 other customer', format($q$select public.admin_order_account_phone(%L)$q$, v_order), 'insufficient_privilege:%');
  perform pg_temp.as_anon();
  perform pg_temp.expect_fail('N2 anon', format($q$select public.admin_order_account_phone(%L)$q$, v_order), 'permission denied%');
  raise notice 'N2 ok - only staff can read an order customer''s verified number';

  -- Q1 a lost response, resolved the way checkout resolves it -------------------
  -- The app keeps one request id until the outcome is known. Whatever it sends
  -- again, no second order appears, and its lookup finds the first.
  perform pg_temp.as_user(c_retail);
  v_req := gen_random_uuid();
  v_res := public.place_order_v3(c_lines, v_work, null, v_req);   -- the answer is lost
  select count(*) into v_n from public.orders;
  if (public.place_order_v3(c_lines, v_work, null, v_req) ->> 'id') <> (v_res ->> 'id') then
    raise exception 'Q1 FAILED - the same retry did not return the first order';
  end if;
  perform pg_temp.expect_fail('Q1 retry with a changed bag',
    format($q$select public.place_order_v3('[{"product_id":"da-item","quantity":1}]', %L, null, %L)$q$, v_work, v_req), 'request_id_reused:%');
  perform pg_temp.expect_fail('Q1 retry with a note added',
    format($q$select public.place_order_v3(%L, %L, 'note', %L)$q$, c_lines, v_work, v_req), 'request_id_reused:%');
  if (select count(*) from public.orders) <> v_n then
    raise exception 'Q1 FAILED - a retry created another order';
  end if;
  -- findMyOrderByRequest's query.
  if (select id from public.orders where profile_id = c_retail and request_id = v_req) <> (v_res ->> 'id')::uuid then
    raise exception 'Q1 FAILED - the customer cannot find the order by its request id';
  end if;
  perform pg_temp.as_user(c_vip);
  if exists (select 1 from public.orders where request_id = v_req) then
    raise exception 'Q1 FAILED - another customer found the order by its request id';
  end if;
  raise notice 'Q1 ok - retries return or refuse, never order twice; only the owner finds the order by request id';

  -- L1 at most 20 saved addresses --------------------------------------------------
  -- Concurrent saves are covered by verify_address_limit_concurrency.sh.
  perform pg_temp.as_user(c_other);
  for i in 2..20 loop
    perform pg_temp.save(p_name := 'Other Person', p_line1 := i || ' Limit Road');
  end loop;
  if (select count(*) from public.addresses) <> 20 then
    raise exception 'L1 FAILED - could not save 20 addresses';
  end if;
  perform pg_temp.expect_fail('L1 21st address', $q$select pg_temp.save(p_name := 'Other Person', p_line1 := '21 Limit Road')$q$, 'address_limit_reached:%');
  perform pg_temp.expect_fail('L1 duplicate at the limit', $q$select pg_temp.save(p_name := 'Other Person', p_line1 := '7 Lake Road')$q$, 'address_duplicate:%');
  -- Editing never counts against the limit.
  perform pg_temp.save(p_id := v_other, p_name := 'Other Person', p_line1 := '7 Lake Road', p_landmark := 'Edited at the limit');
  if (select landmark from public.addresses where id = v_other) <> 'Edited at the limit' then
    raise exception 'L1 FAILED - an edit at the limit was refused';
  end if;
  -- The limit is per customer.
  perform pg_temp.as_user(c_retail);
  perform pg_temp.save(p_name := 'Retail Limit Check', p_line1 := '1 Separate Road');
  perform pg_temp.as_user(c_other);
  perform public.delete_address((select id from public.addresses where line1 = '20 Limit Road'));
  perform pg_temp.save(p_name := 'Other Person', p_line1 := '21 Limit Road');
  if (select count(*) from public.addresses) <> 20 then
    raise exception 'L1 FAILED - deleting one did not make room for another';
  end if;
  raise notice 'L1 ok - a 21st address is refused, edits and other customers are unaffected, deleting makes room';

  perform pg_temp.as_postgres();
end;
$$;

rollback;

\echo ALL DELIVERY ADDRESS CHECKS PASSED
