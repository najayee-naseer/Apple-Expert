-- ============================================================================
-- Apple Expert - dual barcode verification (migration 20261101140000)
-- ----------------------------------------------------------------------------
-- LOCAL ONLY. Run after all migrations and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_dual_barcodes.sql
--
-- One transaction, rolled back. Logged in as postgres to set up fixtures; each
-- check switches to role authenticated, so RLS and grants are armed. Through the
-- API login, verify_dual_barcodes_concurrency.sh arms the stock guard as well.
-- A clean run ends with "ALL DUAL BARCODE CHECKS PASSED".
-- ============================================================================

\set ON_ERROR_STOP on

begin;

create function pg_temp.as_user(p_uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true),
         set_config('role', 'authenticated', true)
$$;
create function pg_temp.as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true), set_config('role', 'anon', true)
$$;
create function pg_temp.as_postgres() returns void language sql as $$
  select set_config('role', 'postgres', true)
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
create function pg_temp.check_true(p_label text, p_ok boolean) returns void language plpgsql as $$
begin
  if p_ok is not true then raise exception '% FAILED', p_label; end if;
end $$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '', now(), now(), now(),
       '{}'::jsonb, '{}'::jsonb, false
from (values ('51111111-1111-1111-1111-111111111111', 'db-admin@test.local'),
             ('52222222-2222-2222-2222-222222222222', 'db-staff@test.local'),
             ('53333333-3333-3333-3333-333333333333', 'db-customer@test.local')) as u(id, email);

insert into public.user_roles (profile_id, role) values
  ('51111111-1111-1111-1111-111111111111', 'admin'),
  ('52222222-2222-2222-2222-222222222222', 'staff');

create function pg_temp.cat(p text) returns uuid language sql as $$ select id from public.categories where slug = p $$;

insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode) values
  ('db-acc',    'DB Cable',   pg_temp.cat('accessories'), 'Other Accessories', 10, true, 'quantity'),
  ('db-part',   'DB Screen',  pg_temp.cat('parts'),       'Displays',           5, false, 'quantity'),
  ('db-var',    'DB Case',    pg_temp.cat('accessories'), 'Other Accessories', 10, true, 'quantity'),
  ('db-unit',   'DB Tracker', pg_temp.cat('accessories'), 'Other Accessories',  0, true, 'unit'),
  ('db-iphone', 'DB iPhone',  pg_temp.cat('iphone'),      'Devices',            3, true, 'quantity'),
  ('db-ipad',   'DB iPad',    pg_temp.cat('ipad'),        'Devices',            3, true, 'quantity'),
  ('db-mac',    'DB Mac',     pg_temp.cat('mac'),         'Devices',            3, true, 'quantity'),
  ('db-watch',  'DB Watch',   pg_temp.cat('watch'),       'Devices',            3, true, 'quantity'),
  ('db-pods',   'DB Pods',    pg_temp.cat('airpods'),     'Devices',            3, true, 'quantity');

insert into public.product_variants (id, product_id, legacy_key, name, stock) values
  ('5a000000-0000-0000-0000-00000000000a', 'db-var', 'a', 'Blue', null),
  ('5b000000-0000-0000-0000-00000000000b', 'db-var', 'b', 'Red',  null);

insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty, starts_at) values
  ('db-acc',  null, 'retail', 200000, 1, now() - interval '1 day'),
  ('db-acc',  null, 'wholesale_vip', 150000, 1, now() - interval '1 day'),
  ('db-var',  '5a000000-0000-0000-0000-00000000000a', 'retail', 100000, 1, now() - interval '1 day'),
  ('db-var',  '5b000000-0000-0000-0000-00000000000b', 'retail', 110000, 1, now() - interval '1 day'),
  ('db-unit', null, 'retail', 300000, 1, now() - interval '1 day');

do $$
declare
  c_admin    constant text := '51111111-1111-1111-1111-111111111111';
  c_staff    constant text := '52222222-2222-2222-2222-222222222222';
  c_customer constant text := '53333333-3333-3333-3333-333333333333';
  c_va       constant uuid := '5a000000-0000-0000-0000-00000000000a';
  c_vb       constant uuid := '5b000000-0000-0000-0000-00000000000b';
  v_today    date := (now() at time zone 'Asia/Colombo')::date;
  v_acc      jsonb;
  v_a        jsonb;
  v_b        jsonb;
  v_ean      jsonb;
  v_res      jsonb;
  v_grn      jsonb;
  v_codes    text[];
  v_id       uuid;
  v_order    uuid;
  v_sup      uuid;
  v_moves    bigint;
  v_stock    integer;
  v_t        text;
begin
  -- D0 nothing was created by the migration ---------------------------------------
  perform pg_temp.check_true('D0a no product barcodes exist for these items',
    not exists (select 1 from public.product_barcodes where product_id ~ '^db-'));
  perform pg_temp.check_true('D0b every unit is registered',
    (select count(*) from public.barcode_registry where kind = 'unit') = (select count(*) from public.inventory_units));
  raise notice 'D0 ok - nothing is issued without a request';

  -- D1 devices are blocked, whichever kind of code -----------------------------------
  perform pg_temp.as_user(c_admin);
  foreach v_t in array array['db-iphone', 'db-ipad', 'db-mac', 'db-watch', 'db-pods'] loop
    perform pg_temp.expect_fail('D1a shop ' || v_t,
      format('select public.admin_issue_product_barcode(%L, null)', v_t), 'shared_barcode_not_allowed:%');
    perform pg_temp.expect_fail('D1b manufacturer ' || v_t,
      format('select public.admin_register_manufacturer_barcode(%L, null, %L)', v_t, '4006381333931'), 'shared_barcode_not_allowed:%');
  end loop;
  perform pg_temp.expect_fail('D1c an individually tracked accessory',
    $q$select public.admin_issue_product_barcode('db-unit', null)$q$, 'shared_barcode_not_allowed:%');
  perform pg_temp.expect_fail('D1d admin cannot open a device category',
    $q$update public.categories set allows_shared_barcode = true where slug = 'iphone'$q$, 'shared_barcode_locked:%');
  raise notice 'D1 ok - iPhone, iPad, Mac, Watch, AirPods and tracked items refused';

  -- D2 one exact identity -----------------------------------------------------------
  perform pg_temp.expect_fail('D2a variant required',
    $q$select public.admin_issue_product_barcode('db-var', null)$q$, 'variant_required:%');
  perform pg_temp.expect_fail('D2b variant of another product',
    format('select public.admin_issue_product_barcode(%L, %L::uuid)', 'db-acc', c_va), 'variant_product_mismatch:%');

  v_acc := public.admin_issue_product_barcode('db-acc', null);
  v_a := public.admin_issue_product_barcode('db-var', c_va);
  v_b := public.admin_issue_product_barcode('db-var', c_vb);
  perform pg_temp.check_true('D2c format', v_acc ->> 'value' ~ '^AP[0-9]{8}$' and (v_acc ->> 'created')::boolean);
  perform pg_temp.check_true('D2d each variant has its own', v_a ->> 'value' <> v_b ->> 'value');
  perform pg_temp.check_true('D2e asking again returns the same code',
    public.admin_issue_product_barcode('db-acc', null) ->> 'value' = v_acc ->> 'value'
    and not (public.admin_issue_product_barcode('db-acc', null) ->> 'created')::boolean);
  perform public.admin_issue_product_barcode('db-part', null);
  raise notice 'D2 ok - products without variants and each variant get exactly one shop code';

  -- D3 who may do what ---------------------------------------------------------------
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('D3a staff issue', $q$select public.admin_issue_product_barcode('db-acc', null)$q$, 'insufficient_privilege:%');
  perform pg_temp.expect_fail('D3b staff register', $q$select public.admin_register_manufacturer_barcode('db-acc', null, '4006381333931')$q$, 'insufficient_privilege:%');
  perform pg_temp.check_true('D3c staff can read', (select count(*) from public.product_barcodes) >= 4);
  perform pg_temp.expect_fail('D3d direct insert', $q$insert into public.product_barcodes (product_id, value, source) values ('db-acc', 'AP99999999', 'shop')$q$, 'permission denied%');
  perform pg_temp.expect_fail('D3e direct update', $q$update public.product_barcodes set status = 'retired'$q$, 'permission denied%');
  perform pg_temp.expect_fail('D3f direct delete', $q$delete from public.barcode_registry$q$, 'permission denied%');
  perform pg_temp.as_user(c_customer);
  perform pg_temp.check_true('D3g customers read nothing',
    (select count(*) from public.product_barcodes) = 0 and (select count(*) from public.barcode_registry) = 0);
  perform pg_temp.expect_fail('D3h customer scan', format('select public.pos_scan(%L, null)', v_acc ->> 'value'), 'insufficient_privilege:%');
  perform pg_temp.as_anon();
  perform pg_temp.expect_fail('D3i anon table', 'select 1 from public.product_barcodes', 'permission denied%');
  perform pg_temp.expect_fail('D3j anon scan', format('select public.pos_scan(%L, null)', v_acc ->> 'value'), 'permission denied%');
  raise notice 'D3 ok - lookup is staff-only, issuing is admin-only, nobody writes directly';

  -- D4 manufacturer codes ------------------------------------------------------------
  perform pg_temp.as_user(c_admin);
  perform pg_temp.expect_fail('D4a bad check digit', $q$select public.admin_register_manufacturer_barcode('db-acc', null, '4006381333932')$q$, 'invalid_barcode:%');
  perform pg_temp.expect_fail('D4b wrong length', $q$select public.admin_register_manufacturer_barcode('db-acc', null, '123456789')$q$, 'invalid_barcode:%');
  -- UPC-A 036000291452 is the same product as EAN-13 0036000291452.
  v_ean := public.admin_register_manufacturer_barcode('db-acc', null, '036000291452');
  perform pg_temp.check_true('D4c registered', (v_ean ->> 'created')::boolean);
  perform pg_temp.check_true('D4d same code in EAN-13 form is the same barcode',
    public.admin_register_manufacturer_barcode('db-acc', null, '0036000291452') ->> 'id' = v_ean ->> 'id');
  perform pg_temp.expect_fail('D4e another item', format('select public.admin_register_manufacturer_barcode(%L, %L::uuid, %L)', 'db-var', c_va, '0036000291452'), 'barcode_in_use:%');
  perform pg_temp.check_true('D4f EAN-8', (public.admin_register_manufacturer_barcode('db-var', c_va, '96385074') ->> 'created')::boolean);
  perform pg_temp.check_true('D4g EAN-13', (public.admin_register_manufacturer_barcode('db-var', c_vb, '4006381333931') ->> 'created')::boolean);
  perform pg_temp.check_true('D4h an item may have several',
    (select count(*) from public.product_barcodes where product_id = 'db-var' and variant_id = c_va) = 2);
  raise notice 'D4 ok - EAN-8, UPC-A and EAN-13 validate; UPC-A and EAN-13 forms are one barcode';

  -- D5 scanning a product barcode ---------------------------------------------------
  perform pg_temp.as_user(c_staff);
  v_res := public.pos_scan(v_acc ->> 'value', null);
  perform pg_temp.check_true('D5a shop code -> product',
    v_res ->> 'kind' = 'product' and v_res ->> 'product_id' = 'db-acc' and v_res ->> 'variant_id' is null and (v_res ->> 'price_cents')::bigint = 200000);
  v_res := public.pos_scan(lower(v_b ->> 'value'), null);
  perform pg_temp.check_true('D5b lower case -> exact variant', (v_res ->> 'variant_id')::uuid = c_vb and (v_res ->> 'price_cents')::bigint = 110000);
  perform pg_temp.check_true('D5c UPC-A -> product', public.pos_scan('036000291452', null) ->> 'product_id' = 'db-acc');
  perform pg_temp.check_true('D5d EAN-13 of it -> same product', public.pos_scan('0036000291452', null) ->> 'product_id' = 'db-acc');
  perform pg_temp.check_true('D5e manufacturer and shop code agree',
    public.pos_scan('96385074', null) ->> 'variant_id' = public.pos_scan(v_a ->> 'value', null) ->> 'variant_id');
  perform pg_temp.expect_fail('D5f unknown', $q$select public.pos_scan('AP99999998', null)$q$, 'unit_not_found:%');
  perform pg_temp.check_true('D5g no cost in the result', public.pos_scan(v_acc ->> 'value', null)::text !~* 'cost');
  raise notice 'D5 ok - every form of a product barcode resolves to one exact product/variant';

  -- D6 unit barcodes and every status ---------------------------------------------------
  perform pg_temp.as_user(c_admin);
  v_sup := (public.admin_save_supplier(null, 'DB Supplier', null, null, null, null, null, null, null, true) ->> 'id')::uuid;
  v_grn := public.admin_receive_goods('supplier', v_sup, null, null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'db-unit', 'received_quantity', 6, 'unit_cost_cents', 700,
      'serials', jsonb_build_array('DBSERIAL0001', 'DBSERIAL0002', 'DBSERIAL0003', 'DBSERIAL0004', 'DBSERIAL0005', 'DBSERIAL0006'))),
    gen_random_uuid());
  select array_agg(barcode order by fifo_seq) into v_codes from public.inventory_units where product_id = 'db-unit';
  perform pg_temp.check_true('D6a every new unit registered', (select count(*) from public.barcode_registry r where r.value = any (v_codes) and r.kind = 'unit') = 6);

  perform pg_temp.as_user(c_staff);
  v_res := public.pos_scan(v_codes[6], null);
  perform pg_temp.check_true('D6b unit barcode -> exact unit',
    v_res ->> 'kind' = 'unit' and v_res ->> 'barcode' = v_codes[6] and v_res ->> 'status' = 'in_stock' and v_res ->> 'serial_number' = 'DBSERIAL0006');
  perform pg_temp.check_true('D6c serial -> same unit', public.pos_scan('dbserial0006', null) ->> 'unit_id' = v_res ->> 'unit_id');
  perform pg_temp.check_true('D6d no cost in the result', v_res::text !~* 'cost');

  -- reserved (oldest first)
  perform pg_temp.as_user(c_customer);
  v_order := (pg_temp.place_order('[{"product_id":"db-unit","quantity":1}]'::jsonb) ->> 'id')::uuid;
  perform pg_temp.as_user(c_staff);
  perform pg_temp.check_true('D6e reserved', public.pos_scan(v_codes[1], null) ->> 'status' = 'reserved');
  perform pg_temp.expect_fail('D6f reserved cannot be sold',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())', jsonb_build_array(jsonb_build_object('code', v_codes[1])), 'cash'),
    'unit_not_available:%');

  -- sold
  v_res := public.pos_create_sale(jsonb_build_array(jsonb_build_object('code', v_codes[2])), 'cash', null, 0, null, null, null, null, null, gen_random_uuid());
  perform pg_temp.check_true('D6g sold', public.pos_scan(v_codes[2], null) ->> 'status' = 'sold');

  -- quarantined, written off, returned to supplier
  perform pg_temp.as_user(c_admin);
  select id into v_id from public.inventory_units where barcode = v_codes[3];
  perform public.admin_quarantine_units(array[v_id], 'doubtful');
  select id into v_id from public.inventory_units where barcode = v_codes[4];
  perform public.admin_write_off_units(array[v_id], 'damage', 'dropped');
  perform public.admin_create_supplier_return(v_sup, v_today, 'credit', array[v_codes[5]], null, 'faulty', gen_random_uuid());
  perform pg_temp.as_user(c_staff);
  perform pg_temp.check_true('D6h quarantined', public.pos_scan(v_codes[3], null) ->> 'status' = 'quarantined');
  perform pg_temp.check_true('D6i written off', public.pos_scan(v_codes[4], null) ->> 'status' = 'written_off');
  perform pg_temp.check_true('D6j returned', public.pos_scan(v_codes[5], null) ->> 'status' = 'returned_to_supplier');
  foreach v_t in array array[v_codes[2], v_codes[3], v_codes[4], v_codes[5]] loop
    perform pg_temp.expect_fail('D6k cannot be sold ' || v_t,
      format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())', jsonb_build_array(jsonb_build_object('code', v_t)), 'cash'),
      'unit_not_available:%');
  end loop;
  raise notice 'D6 ok - unit barcodes resolve to one unit, and every status reports itself and refuses sale';

  -- D7 re-entry: an old sticker names the barcode the device has now ---------------------
  perform pg_temp.as_user(c_admin);
  perform public.admin_receive_goods('buyback', null, 'A customer', null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'db-unit', 'received_quantity', 1, 'unit_cost_cents', 800,
      'serials', jsonb_build_array('DBSERIAL0002'), 'serial_reentry_reason', 'bought back')), gen_random_uuid());
  perform pg_temp.as_user(c_staff);
  v_res := public.pos_scan(v_codes[2], null);
  perform pg_temp.check_true('D7a old sticker stays that sold unit', v_res ->> 'status' = 'sold' and v_res ->> 'reentered_as' ~ '^AE');
  perform pg_temp.check_true('D7b serial finds the unit in the shop',
    public.pos_scan('DBSERIAL0002', null) ->> 'status' = 'in_stock'
    and public.pos_scan('DBSERIAL0002', null) ->> 'barcode' = v_res ->> 'reentered_as');
  raise notice 'D7 ok - re-entered devices are never confused with their old record';

  -- D8 no collision in any direction ------------------------------------------------------
  perform pg_temp.as_user(c_admin);
  perform pg_temp.expect_fail('D8a serial equal to a registered EAN',
    format('select public.admin_receive_goods(%L, null, null, null, null, false, null, %L::date, null, %L::jsonb, gen_random_uuid())', 'opening', v_today,
      jsonb_build_array(jsonb_build_object('product_id', 'db-unit', 'received_quantity', 1, 'unit_cost_cents', 1, 'serials', jsonb_build_array('4006381333931')))),
    'invalid_serial:%');
  perform pg_temp.expect_fail('D8b serial shaped like a product code',
    format('select public.admin_receive_goods(%L, null, null, null, null, false, null, %L::date, null, %L::jsonb, gen_random_uuid())', 'opening', v_today,
      jsonb_build_array(jsonb_build_object('product_id', 'db-unit', 'received_quantity', 1, 'unit_cost_cents', 1, 'serials', jsonb_build_array('AP00000001')))),
    'invalid_serial:%');
  -- A real device serial that happens to be valid GTIN-13 digits.
  perform public.admin_receive_goods('opening', null, null, null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'db-unit', 'received_quantity', 1, 'unit_cost_cents', 1, 'serials', jsonb_build_array('5901234123457'))),
    gen_random_uuid());
  perform pg_temp.expect_fail('D8c manufacturer code equal to a serial',
    $q$select public.admin_register_manufacturer_barcode('db-acc', null, '5901234123457')$q$, 'barcode_in_use:%');
  -- The registry holds the line even if a function had a bug.
  perform pg_temp.as_postgres();
  perform pg_temp.expect_fail('D8d registry refuses a duplicate value',
    format($q$insert into public.barcode_registry (value, kind, unit_id) values (%L, 'unit', %L::uuid)$q$, v_acc ->> 'value', v_id),
    'duplicate key%');
  perform pg_temp.expect_fail('D8e one active shop code per item',
    $q$insert into public.product_barcodes (product_id, value, source) values ('db-acc', 'AP88888888', 'shop')$q$,
    'duplicate key%');
  raise notice 'D8 ok - unit, product and serial values cannot collide';

  -- D9 retirement is final ------------------------------------------------------------------
  perform pg_temp.as_user(c_admin);
  perform public.admin_retire_product_barcode((v_acc ->> 'id')::uuid, 'label misprinted');
  perform pg_temp.expect_fail('D9a twice', format('select public.admin_retire_product_barcode(%L::uuid, %L)', v_acc ->> 'id', 'again'), 'barcode_retired:%');
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('D9b scan', format('select public.pos_scan(%L, null)', v_acc ->> 'value'), 'barcode_retired:%');
  perform pg_temp.as_user(c_admin);
  v_res := public.admin_issue_product_barcode('db-acc', null);
  perform pg_temp.check_true('D9c a new code, not the old one', v_res ->> 'value' <> v_acc ->> 'value');
  perform public.admin_retire_product_barcode((v_ean ->> 'id')::uuid, 'wrong barcode entered');
  perform pg_temp.expect_fail('D9d retired manufacturer code cannot return',
    $q$select public.admin_register_manufacturer_barcode('db-acc', null, '036000291452')$q$, 'barcode_retired:%');
  perform pg_temp.expect_fail('D9e nor on another item',
    format('select public.admin_register_manufacturer_barcode(%L, %L::uuid, %L)', 'db-var', c_vb, '0036000291452'), 'barcode_retired:%');
  perform pg_temp.as_postgres();
  perform pg_temp.expect_fail('D9f cannot be reactivated',
    format($q$update public.product_barcodes set status = 'active', retired_at = null where id = %L::uuid$q$, v_acc ->> 'id'), 'barcode_retired:%');
  perform pg_temp.expect_fail('D9g value is immutable',
    format($q$update public.product_barcodes set value = 'AP77777777' where id = %L::uuid$q$, v_a ->> 'id'), 'barcode_history:%');
  perform pg_temp.check_true('D9h registry keeps the retired value',
    exists (select 1 from public.barcode_registry where value = v_acc ->> 'value'));
  raise notice 'D9 ok - a retired barcode stays reserved forever';

  -- D10 sale by shared barcode: ledger, atomicity, price ----------------------------------------
  v_moves := (select count(*) from public.inventory_movements where product_id = 'db-var');
  v_stock := (select stock from public.products where id = 'db-var');
  perform pg_temp.check_true('D10a issuing moved no stock', v_stock = 10 and v_moves = 0);

  perform pg_temp.as_user(c_admin);
  v_res := public.pos_create_sale(
    jsonb_build_array(jsonb_build_object('product_id', 'db-var', 'variant_id', c_va, 'quantity', 2)),
    'cash', null, 0, null, null, null, null, null, gen_random_uuid());
  perform pg_temp.check_true('D10b server price', (v_res ->> 'total_cents')::bigint = 200000);
  perform pg_temp.check_true('D10c stock through the ledger',
    (select stock from public.products where id = 'db-var') = 8
    and (select count(*) from public.inventory_movements where product_id = 'db-var' and reason = 'sale') = 1
    and (select sum(delta) from public.inventory_movements where product_id = 'db-var') = -2);
  -- A bad line rolls the whole sale back.
  perform pg_temp.expect_fail('D10d over availability',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 0, null, null, null, null, null, gen_random_uuid())',
      jsonb_build_array(jsonb_build_object('product_id', 'db-var', 'variant_id', c_vb, 'quantity', 1),
                        jsonb_build_object('product_id', 'db-acc', 'quantity', 999)), 'cash'),
    'insufficient_stock:%');
  perform pg_temp.check_true('D10e nothing moved', (select stock from public.products where id = 'db-var') = 8);

  -- Wholesale price at the served account's tier.
  perform pg_temp.as_postgres();
  update public.profiles set customer_type = 'wholesale_vip' where id = c_customer::uuid;
  perform pg_temp.as_user(c_staff);
  v_res := public.pos_scan((select value from public.product_barcodes where product_id = 'db-acc' and source = 'shop' and status = 'active'), c_customer::uuid);
  perform pg_temp.check_true('D10f wholesale price when an account is served', (v_res ->> 'price_cents')::bigint = 150000);
  raise notice 'D10 ok - shared-barcode sales go through the ledger, atomically, at server prices';

  -- D11 a barcode stops working when its item becomes individually tracked --------------------
  perform pg_temp.as_postgres();
  update public.products set tracking_mode = 'unit' where id = 'db-acc';
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('D11 scan after switching',
    format('select public.pos_scan(%L, null)', (select value from public.product_barcodes where product_id = 'db-acc' and source = 'shop' and status = 'active')),
    'scan_required:%');
  perform pg_temp.as_postgres();
  update public.products set category_id = pg_temp.cat('iphone') where id = 'db-var';
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('D11b scan after moving to a device category',
    format('select public.pos_scan(%L, null)', v_a ->> 'value'), 'scan_required:%');
  raise notice 'D11 ok - a shared barcode never sells an individually tracked item or a device';

  -- D12 purchase costs stay closed ----------------------------------------------------------------
  perform pg_temp.expect_fail('D12a unit cost', 'select unit_cost_cents from public.inventory_units limit 1', 'permission denied%');
  perform pg_temp.check_true('D12b the new tables hold no cost',
    not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name in ('product_barcodes', 'barcode_registry') and column_name ~* 'cost'));
  raise notice 'D12 ok - cost privileges unchanged';

  raise notice 'ALL DUAL BARCODE CHECKS PASSED';
end
$$;

rollback;
