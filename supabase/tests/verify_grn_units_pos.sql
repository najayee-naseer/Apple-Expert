-- ============================================================================
-- Apple Expert - GRN, barcode units, FIFO reservation and POS verification
-- ----------------------------------------------------------------------------
-- Updated for 20261101100000-130000: orders hold stock instead of taking it, the
-- number falls on first shipment, and returns go to quarantine.
-- NOT YET EXECUTED against the updated migrations.
--
-- Run AFTER all migrations and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_grn_units_pos.sql
--
-- Like verify_inventory_ledger_authenticator.sql, the checks run through the
-- real API login (authenticator -> role authenticated), so every SECURITY
-- DEFINER function runs as a NON-operator session and the stock guard is fully
-- armed. Fixtures are committed (the second login cannot see an uncommitted
-- transaction) and removed at the start of every run; the checks themselves
-- run in one transaction that is rolled back.
-- A clean run ends with "ALL GRN / UNIT / POS CHECKS PASSED".
-- ============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Setup as postgres (committed). Cleanup first, so a failed run can be re-run.
-- ---------------------------------------------------------------------------
begin;
delete from public.inventory_movements where product_id like 'gt-%';
delete from public.customer_return_items where product_id like 'gt-%';
delete from public.quarantine_lots where product_id like 'gt-%';
delete from public.stock_reservations where product_id like 'gt-%';
delete from public.inventory_units where product_id like 'gt-%';
delete from public.grn_lines where product_id like 'gt-%';
delete from public.grns where supplier_name like 'gt-%';
update public.product_variants set stock = 0 where product_id like 'gt-%' and stock is not null;
update public.products set stock = 0 where id like 'gt-%';
delete from public.products where id like 'gt-%';
delete from public.categories where slug = 'gt-phones';
delete from auth.users where id in ('91111111-1111-1111-1111-111111111111',
                                    '92222222-2222-2222-2222-222222222222',
                                    '93333333-3333-3333-3333-333333333333');
commit;

begin;
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '',
       now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false
from (values
  ('91111111-1111-1111-1111-111111111111', 'gt-admin@test.local'),
  ('92222222-2222-2222-2222-222222222222', 'gt-staff@test.local'),
  ('93333333-3333-3333-3333-333333333333', 'gt-customer@test.local')
) as u(id, email);

insert into public.user_roles (profile_id, role) values
  ('91111111-1111-1111-1111-111111111111', 'admin'),
  ('92222222-2222-2222-2222-222222222222', 'staff');

-- A category that requires an IMEI / serial (as iPhone does after the migration).
insert into public.categories (slug, name, sort_order, is_active, requires_serial)
values ('gt-phones', 'GT Phones', 99, false, true);

-- A phone (IMEI required) with two variants sharing stock,
-- a case with no variants, and an item that still carries untracked stock.
insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode) values
  ('gt-phone',  'GT Phone',  (select id from public.categories where slug = 'gt-phones'),   'Devices',           0, true, 'unit'),
  ('gt-case',   'GT Case',   (select id from public.categories where slug = 'accessories'), 'Other Accessories', 0, true, 'unit'),
  ('gt-legacy', 'GT Legacy', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 5, true, 'quantity');

insert into public.product_variants (id, product_id, legacy_key, name, stock) values
  ('9a000000-0000-0000-0000-00000000000a', 'gt-phone', 'v1', 'Blue 128GB', null),
  ('9b000000-0000-0000-0000-00000000000b', 'gt-phone', 'v2', 'Black 256GB', null);

insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty, starts_at) values
  ('gt-phone',  '9a000000-0000-0000-0000-00000000000a', 'retail', 20000000, 1, now() - interval '1 day'),
  ('gt-phone',  '9b000000-0000-0000-0000-00000000000b', 'retail', 25000000, 1, now() - interval '1 day'),
  ('gt-case',   null,                                   'retail',   300000, 1, now() - interval '1 day'),
  ('gt-legacy', null,                                   'retail',   100000, 1, now() - interval '1 day');
commit;


-- ---------------------------------------------------------------------------
-- As the API
-- ---------------------------------------------------------------------------
\connect "host=127.0.0.1 dbname=postgres user=authenticator"

begin;
set local role authenticated;

-- Temp functions end with the session, so the shared order helper is redefined here.
create function pg_temp.fixture_address() returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  select id into v_id from public.addresses where profile_id = auth.uid() order by is_default desc limit 1;
  if v_id is null then
    v_id := public.save_address(null, 'Test', 'Test Recipient', '+94771234567', 'Western Province', 'Colombo',
                                'Colombo', '1 Test Street', null, null, null, null, true);
  end if;
  return v_id;
end;
$$;
create function pg_temp.place_order(p_lines jsonb, p_notes text default null) returns jsonb language sql as $$
  select public.place_order_v3(p_lines, pg_temp.fixture_address(), p_notes, gen_random_uuid())
$$;
create function pg_temp.place_order_v2(p_lines jsonb, p_notes text, p_request_id uuid) returns jsonb language sql as $$
  select public.place_order_v3(p_lines, pg_temp.fixture_address(), p_notes, p_request_id)
$$;

create function pg_temp.as_user(p_uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true)
$$;

create function pg_temp.expect_fail(p_label text, p_sql text, p_like text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm like p_like then
      return;
    end if;
    raise exception '% FAILED - wrong error: % (sqlstate %)', p_label, sqlerrm, sqlstate;
  end;
  raise exception '% FAILED - statement succeeded: %', p_label, p_sql;
end $$;

-- Staff may read stock, so these read helpers run as whoever is set.
create function pg_temp.stock_of(p text) returns integer language sql as $$
  select stock from public.products where id = p $$;

-- A delivery with no supplier record: the opening-stock path keeps these checks
-- about units, FIFO and POS independent of purchasing (verify_purchase_returns.sql).
create function pg_temp.receive(p_on date, p_lines jsonb, p_req uuid default gen_random_uuid()) returns jsonb language sql as $$
  select public.admin_receive_goods('opening', null, null, null, null, false, null, p_on, null, p_lines, p_req) $$;

create function pg_temp.line(p_product text, p_variant uuid, p_qty integer, p_cost bigint, p_serials jsonb default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('product_id', p_product, 'variant_id', p_variant, 'received_quantity', p_qty,
                                              'unit_cost_cents', p_cost, 'serials', p_serials)) $$;

do $$
declare
  c_admin    constant text := '91111111-1111-1111-1111-111111111111';
  c_staff    constant text := '92222222-2222-2222-2222-222222222222';
  c_customer constant text := '93333333-3333-3333-3333-333333333333';
  c_va       constant uuid := '9a000000-0000-0000-0000-00000000000a';
  c_vb       constant uuid := '9b000000-0000-0000-0000-00000000000b';
  v_today    date := (now() at time zone 'Asia/Colombo')::date;
  v_res      jsonb;
  v_grn1     uuid;
  v_grn2     uuid;
  v_n        integer;
  v_order    jsonb;
  v_order_id uuid;
  v_codes    text[];
  v_barcode  text;
  v_unit     uuid;
  v_sale     jsonb;
  v_total    bigint;
  v_req      uuid := gen_random_uuid();
  v_lines    jsonb;
  v_reserved text;
begin
  if session_user <> 'authenticator' or pg_has_role(session_user, 'postgres', 'MEMBER') then
    raise exception 'G0 FAILED - not running as the API would (session %)', session_user;
  end if;

  -- G1 ---------------------------------------------------------------------
  v_lines := jsonb_build_array(pg_temp.line('gt-case', null, 1, 100));
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('G1a staff GRN',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today, v_lines),
    'insufficient_privilege:%');
  perform pg_temp.as_user(c_customer);
  perform pg_temp.expect_fail('G1b customer POS',
    $q$select public.pos_create_sale('[{"code":"AE00000001"}]'::jsonb, 'cash', null, 0, null, null, null, null, null, gen_random_uuid())$q$,
    'insufficient_privilege:%');
  perform pg_temp.expect_fail('G1c customer lookup', $q$select public.pos_lookup_unit('AE00000001', null)$q$,
    'insufficient_privilege:%');
  perform pg_temp.expect_fail('G1d direct unit insert',
    $q$insert into public.inventory_units (barcode, product_id, grn_id, grn_line_id, received_on)
       values ('AE99999999', 'gt-case', gen_random_uuid(), gen_random_uuid(), current_date)$q$,
    'permission denied%');
  raise notice 'G1 ok - staff cannot post a GRN; customers cannot use POS, lookup or write units';

  -- G2 serial rules ----------------------------------------------------------
  perform pg_temp.as_user(c_admin);
  perform pg_temp.expect_fail('G2a phone without IMEI',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today, jsonb_build_array(pg_temp.line('gt-phone', c_va, 1, 100))),
    'serial_required:%');
  perform pg_temp.expect_fail('G2b bad IMEI check digit',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(pg_temp.line('gt-phone', c_va, 1, 100, jsonb_build_array('356938035643800')))),
    'invalid_imei:%');
  perform pg_temp.expect_fail('G2c duplicate IMEI in one GRN',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(pg_temp.line('gt-phone', c_va, 2, 100, jsonb_build_array('356938035643809', '356938035643809')))),
    'duplicate_serial:%');
  perform pg_temp.expect_fail('G2d serial count mismatch',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(pg_temp.line('gt-phone', c_va, 2, 100, jsonb_build_array('356938035643809')))),
    'invalid_serials:%');
  perform pg_temp.expect_fail('G2e variant required',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(pg_temp.line('gt-phone', null, 1, 100, jsonb_build_array('356938035643809')))),
    'variant_required:%');
  perform pg_temp.expect_fail('G2f future date',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today + 2, v_lines),
    'invalid_date:%');
  perform pg_temp.expect_fail('G2g blank cost is not free',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(jsonb_build_object('product_id', 'gt-case', 'received_quantity', 1))),
    'cost_required:%');
  raise notice 'G2 ok - IMEI required for phones, Luhn checked, duplicates and mismatches refused, blank cost refused';

  -- G3 modes -----------------------------------------------------------------
  perform pg_temp.expect_fail('G3 tracking mode needs zero stock',
    $q$select public.admin_set_tracking_mode('gt-legacy', null, 'unit', 'try to convert')$q$,
    'tracking_mode_locked:%');
  raise notice 'G3 ok - a number cannot silently become unit tracked';

  -- G4 receive 1 -------------------------------------------------------------
  v_res := public.admin_receive_goods('opening', null, null, null, 'INV-77', false, null, v_today - 1, 'first delivery',
    jsonb_build_array(
      pg_temp.line('gt-phone', c_va, 3, 18000000, jsonb_build_array('356938035643809', ' 3569 3803 5643 817 ', '356938035643825')),
      pg_temp.line('gt-phone', c_vb, 2, 22000000, jsonb_build_array('356938035643833', '356938035643841')),
      pg_temp.line('gt-case', null, 4, 150000)),
    v_req);
  v_grn1 := (v_res ->> 'id')::uuid;
  if (v_res ->> 'total_units')::int <> 9 or v_res ->> 'grn_number' !~ '^GRN-[0-9]{6}-[0-9]{4}$' then
    raise exception 'G4 FAILED - GRN result %', v_res;
  end if;
  if pg_temp.stock_of('gt-phone') <> 5 or pg_temp.stock_of('gt-case') <> 4 then
    raise exception 'G4 FAILED - stock phone % case %', pg_temp.stock_of('gt-phone'), pg_temp.stock_of('gt-case');
  end if;
  select count(*) into v_n from public.inventory_units
   where grn_id = v_grn1 and barcode ~ '^AE[0-9]{8}$' and status = 'in_stock';
  if v_n <> 9 then raise exception 'G4 FAILED - % in-stock barcoded units, expected 9', v_n; end if;
  if not exists (select 1 from public.inventory_units where serial_number = '356938035643817') then
    raise exception 'G4 FAILED - serial was not normalised (spaces removed)';
  end if;
  select count(*) into v_n from public.inventory_movements where grn_id = v_grn1;
  if v_n <> 2 then raise exception 'G4 FAILED - % ledger rows for the GRN, expected 2 (one per stock holder)', v_n; end if;
  raise notice 'G4 ok - GRN created 9 barcoded units, stock rose through the ledger';

  -- G5 replay + duplicate serial + Adjust stock refused ------------------------
  v_res := public.admin_receive_goods('opening', null, null, null, 'INV-77', false, null, v_today - 1, 'first delivery',
    jsonb_build_array(
      pg_temp.line('gt-phone', c_va, 3, 18000000, jsonb_build_array('356938035643809', ' 3569 3803 5643 817 ', '356938035643825')),
      pg_temp.line('gt-phone', c_vb, 2, 22000000, jsonb_build_array('356938035643833', '356938035643841')),
      pg_temp.line('gt-case', null, 4, 150000)),
    v_req);
  if not (v_res ->> 'replayed')::boolean or (v_res ->> 'id')::uuid <> v_grn1 then
    raise exception 'G5 FAILED - replay returned %', v_res;
  end if;
  perform pg_temp.expect_fail('G5a request id with other content',
    format('select pg_temp.receive(%L::date, %L::jsonb, %L::uuid)', v_today, v_lines, v_req),
    'request_id_reused:%');
  perform pg_temp.expect_fail('G5b serial in the shop',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(pg_temp.line('gt-phone', c_va, 1, 100, jsonb_build_array('356938035643809')))),
    'duplicate_serial:%');
  perform pg_temp.expect_fail('G5c adjust stock on tracked item',
    $q$select public.admin_set_stock('gt-case', null, 4, 10, 'restock', 'more cases', gen_random_uuid())$q$,
    'unit_tracked:%');
  raise notice 'G5 ok - replay applied once, different content refused, active serials unique, Adjust stock refused';

  -- G6 received EARLIER -> picked first; the order HOLDS, the number stays --------
  v_res := pg_temp.receive(v_today - 5, jsonb_build_array(pg_temp.line('gt-phone', c_va, 1, 100, jsonb_build_array('356938035643858'))));
  v_grn2 := (v_res ->> 'id')::uuid;
  if pg_temp.stock_of('gt-phone') <> 6 then raise exception 'G6 FAILED - phone stock %', pg_temp.stock_of('gt-phone'); end if;

  perform pg_temp.as_user(c_customer);
  select count(*) into v_n from public.inventory_units;
  if v_n <> 0 then raise exception 'G6 FAILED - a customer can read % inventory units', v_n; end if;

  v_req := gen_random_uuid();
  v_order := pg_temp.place_order_v2(jsonb_build_array(jsonb_build_object('product_id', 'gt-phone', 'variant_key', 'v1', 'quantity', 2)), 'gt-fixture', v_req);
  v_order_id := (v_order ->> 'id')::uuid;

  -- Same request, same content: the first order. Different content: refused.
  if (pg_temp.place_order_v2(jsonb_build_array(jsonb_build_object('product_id', 'gt-phone', 'variant_key', 'v1', 'quantity', 2)), 'gt-fixture', v_req) ->> 'id')::uuid <> v_order_id then
    raise exception 'G6 FAILED - order replay created a second order';
  end if;
  perform pg_temp.expect_fail('G6a request id with other content',
    format('select pg_temp.place_order_v2(%L::jsonb, null, %L::uuid)',
           jsonb_build_array(jsonb_build_object('product_id', 'gt-phone', 'variant_key', 'v1', 'quantity', 1)), v_req),
    'request_id_reused:%');

  perform pg_temp.as_user(c_staff);
  if pg_temp.stock_of('gt-phone') <> 6 then raise exception 'G6 FAILED - placing an order moved the number to %', pg_temp.stock_of('gt-phone'); end if;
  if (select stock_state from public.orders where id = v_order_id) <> 'reserved'
     or (select reservation_expires_at from public.orders where id = v_order_id) is null then
    raise exception 'G6 FAILED - order not reserved with an expiry';
  end if;
  select array_agg(serial_number order by received_on, fifo_seq) into v_codes
    from public.inventory_units where order_id = v_order_id and status = 'reserved';
  if v_codes is distinct from array['356938035643858', '356938035643809'] then
    raise exception 'G6 FAILED - FIFO picked %', v_codes;
  end if;
  raise notice 'G6 ok - online order holds the oldest units; the number is unmoved; request id is idempotent';

  -- G7 variant without enough units --------------------------------------------
  perform pg_temp.as_user(c_customer);
  perform pg_temp.expect_fail('G7 variant B over units',
    $q$select pg_temp.place_order('[{"product_id":"gt-phone","variant_key":"v2","quantity":3}]'::jsonb, 'gt-fixture')$q$,
    'insufficient_stock:%');
  if (select available from public.catalog_availability() a where a.product_id = 'gt-phone' and a.legacy_key = 'v2') <> 2
     or (select available from public.catalog_availability() a where a.product_id = 'gt-phone' and a.legacy_key = 'v1') <> 2 then
    raise exception 'G7 FAILED - per-variant availability is wrong';
  end if;
  raise notice 'G7 ok - availability is per variant, an order larger than it is refused';

  -- G8 cancel / re-activate / confirm / ship -------------------------------------
  perform pg_temp.as_user(c_staff);
  update public.orders set status = 'cancelled' where id = v_order_id;
  if pg_temp.stock_of('gt-phone') <> 6
     or exists (select 1 from public.inventory_units where order_id = v_order_id)
     or (select stock_state from public.orders where id = v_order_id) <> 'released' then
    raise exception 'G8 FAILED - cancel did not release (stock %)', pg_temp.stock_of('gt-phone');
  end if;
  update public.orders set status = 'confirmed' where id = v_order_id;
  if pg_temp.stock_of('gt-phone') <> 6
     or (select count(*) from public.inventory_units where order_id = v_order_id and status = 'reserved') <> 2
     or (select reservation_expires_at from public.orders where id = v_order_id) is not null then
    raise exception 'G8 FAILED - re-activation should hold again, and confirmed orders never expire';
  end if;
  update public.orders set status = 'shipped' where id = v_order_id;
  if pg_temp.stock_of('gt-phone') <> 4
     or (select count(*) from public.inventory_units where order_id = v_order_id and status = 'sold') <> 2
     or (select stock_state from public.orders where id = v_order_id) <> 'consumed' then
    raise exception 'G8 FAILED - first shipment should deduct once (stock %)', pg_temp.stock_of('gt-phone');
  end if;
  -- Exactly once, whatever the status does next.
  update public.orders set status = 'delivered' where id = v_order_id;
  update public.orders set status = 'processing' where id = v_order_id;
  update public.orders set status = 'shipped' where id = v_order_id;
  if pg_temp.stock_of('gt-phone') <> 4 then raise exception 'G8 FAILED - deducted twice: stock %', pg_temp.stock_of('gt-phone'); end if;
  if (select count(*) from public.inventory_movements where order_id = v_order_id and reason = 'sale') <> 1 then
    raise exception 'G8 FAILED - expected one sale ledger row per line';
  end if;
  -- Cancel after shipping does not restore stock.
  update public.orders set status = 'cancelled' where id = v_order_id;
  if pg_temp.stock_of('gt-phone') <> 4
     or (select count(*) from public.inventory_units where order_id = v_order_id and status = 'sold') <> 2 then
    raise exception 'G8 FAILED - cancelling a shipped order must not restore stock';
  end if;
  raise notice 'G8 ok - cancel releases, reactivate holds, first shipment deducts exactly once, cancel after shipping restores nothing';

  -- G9 POS ---------------------------------------------------------------------
  select barcode into v_barcode from public.inventory_units
   where product_id = 'gt-case' and status = 'in_stock' order by fifo_seq limit 1;
  v_res := public.pos_lookup_unit(lower(v_barcode), null);
  if v_res ->> 'barcode' <> v_barcode or (v_res ->> 'price_cents')::bigint <> 300000 then
    raise exception 'G9 FAILED - lookup by barcode %', v_res;
  end if;
  v_res := public.pos_lookup_unit('356938035643833', null);
  if v_res ->> 'variant_name' <> 'Black 256GB' or (v_res ->> 'price_cents')::bigint <> 25000000 then
    raise exception 'G9 FAILED - lookup by IMEI %', v_res;
  end if;

  -- A unit held by an online order cannot be sold at the counter.
  perform pg_temp.as_user(c_customer);
  v_order := pg_temp.place_order('[{"product_id":"gt-phone","variant_key":"v1","quantity":1}]'::jsonb, 'gt-fixture');
  perform pg_temp.as_user(c_staff);
  select barcode into v_reserved from public.inventory_units where order_id = (v_order ->> 'id')::uuid limit 1;
  perform pg_temp.expect_fail('G9a reserved unit',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())',
           jsonb_build_array(jsonb_build_object('code', v_reserved)), 'cash'),
    'unit_not_available:%');
  update public.orders set status = 'cancelled' where id = (v_order ->> 'id')::uuid;

  perform pg_temp.expect_fail('G9b scanned twice',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())',
           jsonb_build_array(jsonb_build_object('code', v_barcode), jsonb_build_object('code', v_barcode)), 'cash'),
    'duplicate_item:%');
  perform pg_temp.expect_fail('G9c discount too big',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 999999999, null, null, null, null, null, gen_random_uuid())',
           jsonb_build_array(jsonb_build_object('code', v_barcode)), 'cash'),
    'invalid_discount:%');
  -- Default staff limit is 0%: any staff discount needs approval.
  perform pg_temp.expect_fail('G9d staff discount needs approval',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 100, null, null, null, null, null, gen_random_uuid())',
           jsonb_build_array(jsonb_build_object('code', v_barcode)), 'cash'),
    'discount_approval_required:%');

  perform pg_temp.as_user(c_admin);
  v_req := gen_random_uuid();
  v_sale := public.pos_create_sale(jsonb_build_array(jsonb_build_object('code', v_barcode), jsonb_build_object('code', '3569 3803 5643 833')),
                                   'card', null, 50000, 'gt-fixture', '0771234567', null, null, null, v_req);
  v_total := 300000 + 25000000 - 50000;
  if (v_sale ->> 'total_cents')::bigint <> v_total or v_sale ->> 'bill_number' !~ '^POS-[0-9]{6}-[0-9]{5}$' then
    raise exception 'G9 FAILED - bill %', v_sale;
  end if;
  if pg_temp.stock_of('gt-case') <> 3 or pg_temp.stock_of('gt-phone') <> 3 then
    raise exception 'G9 FAILED - stock after POS case % phone %', pg_temp.stock_of('gt-case'), pg_temp.stock_of('gt-phone');
  end if;
  if (select count(*) from public.inventory_units where pos_sale_id = (v_sale ->> 'id')::uuid and status = 'sold') <> 2 then
    raise exception 'G9 FAILED - units not marked sold';
  end if;
  v_res := public.pos_create_sale(jsonb_build_array(jsonb_build_object('code', v_barcode), jsonb_build_object('code', '3569 3803 5643 833')),
                                  'card', null, 50000, 'gt-fixture', '0771234567', null, null, null, v_req);
  if not (v_res ->> 'replayed')::boolean then raise exception 'G9 FAILED - POS replay %', v_res; end if;
  perform pg_temp.expect_fail('G9e sell again',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())',
           jsonb_build_array(jsonb_build_object('code', v_barcode)), 'cash'),
    'unit_not_available:%');
  raise notice 'G9 ok - scan by barcode or IMEI, server prices, discount rule, exactly those units sold, replay safe';

  -- G10 write-off, return to quarantine, release, IMEI re-entry -------------------
  select id into v_unit from public.inventory_units where product_id = 'gt-case' and status = 'in_stock' limit 1;
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('G10a staff write-off',
    format('select public.admin_write_off_units(array[%L::uuid], %L, %L)', v_unit, 'damage', 'cracked'),
    'insufficient_privilege:%');
  perform pg_temp.as_user(c_admin);
  perform public.admin_write_off_units(array[v_unit], 'damage', 'cracked in store');
  if pg_temp.stock_of('gt-case') <> 2 or (select status from public.inventory_units where id = v_unit) <> 'written_off' then
    raise exception 'G10 FAILED - write-off';
  end if;

  -- The customer brings a counter sale back: quarantine, no stock, no money.
  select id into v_unit from public.inventory_units where barcode = v_barcode;
  v_res := public.admin_record_customer_return('pos', (v_sale ->> 'id')::uuid,
    jsonb_build_array(jsonb_build_object('line_id', (select id from public.pos_sale_items where unit_id = v_unit), 'quantity', 1, 'condition', 'unverified')),
    'changed mind', gen_random_uuid());
  if pg_temp.stock_of('gt-case') <> 2 or (select status from public.inventory_units where id = v_unit) <> 'quarantined'
     or exists (select 1 from public.customer_refunds where pos_sale_id = (v_sale ->> 'id')::uuid) then
    raise exception 'G10 FAILED - return must quarantine, with no stock and no refund';
  end if;
  perform pg_temp.expect_fail('G10b quarantined unit cannot be sold',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())',
           jsonb_build_array(jsonb_build_object('code', v_barcode)), 'cash'),
    'unit_not_available:%');
  perform public.admin_release_quarantine_units(array[v_unit], 'checked and sealed');
  if pg_temp.stock_of('gt-case') <> 3 or (select status from public.inventory_units where id = v_unit) <> 'in_stock' then
    raise exception 'G10 FAILED - release';
  end if;

  -- A refund is its own fact, capped at what was charged.
  perform public.admin_record_customer_refund('pos', (v_sale ->> 'id')::uuid, null, 100000, 'cash', null, null, gen_random_uuid());
  if pg_temp.stock_of('gt-case') <> 3 then raise exception 'G10 FAILED - a refund moved stock'; end if;
  perform pg_temp.expect_fail('G10c refund above the bill',
    format('select public.admin_record_customer_refund(%L, %L::uuid, null, %s, %L, null, null, gen_random_uuid())',
           'pos', v_sale ->> 'id', v_total, 'cash'),
    'refund_exceeds_paid:%');

  -- A sold IMEI can come back only with a stated reason, and gets a new barcode.
  perform pg_temp.expect_fail('G10d re-entry without a reason',
    format('select pg_temp.receive(%L::date, %L::jsonb)', v_today,
      jsonb_build_array(pg_temp.line('gt-phone', c_va, 1, 100, jsonb_build_array('356938035643833')))),
    'serial_previously_recorded:%');
  raise notice 'G10 ok - write-off, quarantine, release, separate refund, IMEI re-entry guarded';

  -- G11 quantity item works as a number, with holds ---------------------------------
  perform pg_temp.as_user(c_customer);
  v_order := pg_temp.place_order('[{"product_id":"gt-legacy","quantity":2}]'::jsonb, 'gt-fixture');
  perform pg_temp.as_user(c_staff);
  if pg_temp.stock_of('gt-legacy') <> 5
     or (select available from public.catalog_availability() a where a.product_id = 'gt-legacy' and a.variant_id is null) <> 3 then
    raise exception 'G11 FAILED - a hold must lower availability only';
  end if;
  perform pg_temp.as_user(c_admin);
  perform pg_temp.expect_fail('G11a adjust below holds',
    $q$select public.admin_set_stock('gt-legacy', null, 5, 1, 'stock_count', 'count', gen_random_uuid())$q$,
    'stock_reserved:%');
  perform pg_temp.as_user(c_staff);
  update public.orders set status = 'cancelled' where id = (v_order ->> 'id')::uuid;
  if (select available from public.catalog_availability() a where a.product_id = 'gt-legacy' and a.variant_id is null) <> 5 then
    raise exception 'G11 FAILED - cancel did not release the hold';
  end if;
  raise notice 'G11 ok - quantity items hold without moving the number; stock cannot go below holds';

  -- G12 the invariant: tracked number = units in the shop, ledger sums to the number --
  if pg_temp.stock_of('gt-phone') <> (select count(*) from public.inventory_units where product_id = 'gt-phone' and status in ('in_stock', 'reserved'))
     or pg_temp.stock_of('gt-case') <> (select count(*) from public.inventory_units where product_id = 'gt-case' and status in ('in_stock', 'reserved')) then
    raise exception 'G12 FAILED - stock and shop units disagree';
  end if;
  if (select sum(delta) from public.inventory_movements where product_id = 'gt-phone') <> pg_temp.stock_of('gt-phone')
     or (select sum(delta) from public.inventory_movements where product_id = 'gt-case') <> pg_temp.stock_of('gt-case') then
    raise exception 'G12 FAILED - ledger does not sum to stock';
  end if;
  raise notice 'G12 ok - for tracked items, stock = units in the shop = sum of the ledger';
end $$;

rollback;

\connect "dbname=postgres user=postgres"

-- Remove the committed fixtures (the checks above were rolled back).
begin;
delete from public.inventory_movements where product_id like 'gt-%';
delete from public.customer_return_items where product_id like 'gt-%';
delete from public.quarantine_lots where product_id like 'gt-%';
delete from public.stock_reservations where product_id like 'gt-%';
delete from public.inventory_units where product_id like 'gt-%';
delete from public.grn_lines where product_id like 'gt-%';
delete from public.grns where supplier_name like 'gt-%';
update public.product_variants set stock = 0 where product_id like 'gt-%' and stock is not null;
update public.products set stock = 0 where id like 'gt-%';
delete from public.products where id like 'gt-%';
delete from public.categories where slug = 'gt-phones';
delete from auth.users where id in ('91111111-1111-1111-1111-111111111111',
                                    '92222222-2222-2222-2222-222222222222',
                                    '93333333-3333-3333-3333-333333333333');
commit;

do $$ begin raise notice 'ALL GRN / UNIT / POS CHECKS PASSED'; end $$;
