-- ============================================================================
-- Apple Expert - inventory integration verification (migrations 20261101*)
-- ----------------------------------------------------------------------------
-- LOCAL ONLY. NOT YET EXECUTED: written with the migrations, for the database
-- integration phase. Run after all migrations and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_inventory_master.sql
--
-- Runs in one transaction that is rolled back. It stays logged in as postgres
-- because it must age reservations and create pre-rollout orders; each check
-- switches to role authenticated, so RLS and column privileges are armed. The
-- stock guard's own non-operator path is covered by verify_grn_units_pos.sql.
-- A clean run ends with "ALL INVENTORY MASTER CHECKS PASSED".
-- ============================================================================

\set ON_ERROR_STOP on

begin;

create function pg_temp.as_user(p_uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true),
         set_config('role', 'authenticated', true)
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
create function pg_temp.avail(p_product text, p_variant uuid) returns integer language sql as $$
  select a.available from public.catalog_availability() a
   where a.product_id = p_product and a.variant_id is not distinct from p_variant
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '', now(), now(), now(),
       '{}'::jsonb, '{}'::jsonb, false
from (values ('71111111-1111-1111-1111-111111111111', 'mt-admin@test.local'),
             ('72222222-2222-2222-2222-222222222222', 'mt-staff@test.local'),
             ('73333333-3333-3333-3333-333333333333', 'mt-customer@test.local')) as u(id, email);

insert into public.user_roles (profile_id, role) values
  ('71111111-1111-1111-1111-111111111111', 'admin'),
  ('72222222-2222-2222-2222-222222222222', 'staff');

insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode) values
  ('mt-mix',  'MT Mixed',  (select id from public.categories where slug = 'accessories'), 'Other Accessories', 0, true, 'quantity'),
  ('mt-num',  'MT Number', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 20, true, 'quantity'),
  ('mt-unit', 'MT Unit',   (select id from public.categories where slug = 'accessories'), 'Other Accessories', 0, true, 'unit');

-- Two own-stock variants of one product: one tracked by unit, one by number.
insert into public.product_variants (id, product_id, legacy_key, name, stock, tracking_mode) values
  ('7a000000-0000-0000-0000-00000000000a', 'mt-mix', 'a', 'Own, units',  0, 'unit'),
  ('7b000000-0000-0000-0000-00000000000b', 'mt-mix', 'b', 'Own, number', 5, 'quantity');

insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty, starts_at) values
  ('mt-mix',  '7a000000-0000-0000-0000-00000000000a', 'retail', 100000, 1, now() - interval '1 day'),
  ('mt-mix',  '7b000000-0000-0000-0000-00000000000b', 'retail', 110000, 1, now() - interval '1 day'),
  ('mt-num',  null, 'retail', 200000, 1, now() - interval '1 day'),
  ('mt-num',  null, 'wholesale_vip', 150000, 1, now() - interval '1 day'),
  ('mt-unit', null, 'retail', 300000, 1, now() - interval '1 day');

do $$
declare
  c_admin    constant text := '71111111-1111-1111-1111-111111111111';
  c_staff    constant text := '72222222-2222-2222-2222-222222222222';
  c_customer constant text := '73333333-3333-3333-3333-333333333333';
  c_va       constant uuid := '7a000000-0000-0000-0000-00000000000a';
  c_vb       constant uuid := '7b000000-0000-0000-0000-00000000000b';
  v_today    date := (now() at time zone 'Asia/Colombo')::date;
  v_sup      uuid;
  v_po       uuid;
  v_grn      jsonb;
  v_line     uuid;
  v_res      jsonb;
  v_order    uuid;
  v_id       uuid;
  v_code     text;
  v_req      uuid;
  v_item     uuid;
  v_ret      uuid;
  v_lot      uuid;
  v_approval uuid;
  v_items    jsonb;
begin
  -- M1 a variant is not stuck because a sibling is tracked -----------------------
  perform pg_temp.as_user(c_admin);
  perform public.admin_receive_goods('opening', null, null, null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-mix', 'variant_id', c_va, 'received_quantity', 2, 'unit_cost_cents', 500)),
    gen_random_uuid());
  perform public.admin_set_stock('mt-mix', c_vb, 5, 4, 'stock_count', 'count of B', gen_random_uuid());
  perform pg_temp.check_true('M1a own-stock sibling stays adjustable', (select stock from public.product_variants where id = c_vb) = 4);
  perform public.admin_receive_goods('opening', null, null, null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-mix', 'variant_id', c_vb, 'received_quantity', 1, 'unit_cost_cents', 500)),
    gen_random_uuid());
  perform pg_temp.check_true('M1b own-stock sibling stays receivable', (select stock from public.product_variants where id = c_vb) = 5);
  perform pg_temp.check_true('M1c no unit created for the quantity variant',
    not exists (select 1 from public.inventory_units u where u.variant_id = c_vb));
  perform pg_temp.check_true('M1d availability per holder', pg_temp.avail('mt-mix', c_va) = 2 and pg_temp.avail('mt-mix', c_vb) = 5);
  perform pg_temp.check_true('M1e product aggregate', pg_temp.avail('mt-mix', null) = 7);
  perform pg_temp.expect_fail('M1f adjust the unit variant',
    format('select public.admin_set_stock(%L, %L::uuid, 2, 5, %L, %L, gen_random_uuid())', 'mt-mix', c_va, 'restock', 'not allowed'),
    'unit_tracked:%');
  raise notice 'M1 ok - tracking is per stock holder';

  -- M2 reservation expiry ----------------------------------------------------------
  perform pg_temp.as_user(c_customer);
  v_order := (public.place_order('[{"product_id":"mt-num","quantity":3}]'::jsonb) ->> 'id')::uuid;
  perform pg_temp.check_true('M2a hold lowers availability, not stock',
    pg_temp.avail('mt-num', null) = 17 and (select stock from public.products where id = 'mt-num') = 20);

  -- Age it: overdue holds stop counting at once, before any sweep has run.
  perform pg_temp.as_postgres();
  update public.orders set reservation_expires_at = now() - interval '1 minute' where id = v_order;
  update public.stock_reservations set expires_at = now() - interval '1 minute' where order_id = v_order;
  perform pg_temp.check_true('M2b overdue hold no longer counts', pg_temp.avail('mt-num', null) = 20);

  perform pg_temp.as_user(c_customer);
  perform pg_temp.expect_fail('M2c customers cannot run expiry', 'select public.expire_pending_orders(10)', 'insufficient_privilege:%');
  perform pg_temp.as_user(c_staff);
  perform pg_temp.check_true('M2d expiry cancels it', (public.expire_pending_orders(10) ->> 'expired')::integer >= 1);
  perform pg_temp.check_true('M2e state',
    (select status from public.orders where id = v_order) = 'cancelled'
    and (select stock_state from public.orders where id = v_order) = 'expired'
    and (select status from public.stock_reservations where order_id = v_order) = 'expired');
  perform pg_temp.check_true('M2f running again changes nothing', (public.expire_pending_orders(10) ->> 'expired')::integer = 0);
  perform pg_temp.check_true('M2g stock never moved', (select stock from public.products where id = 'mt-num') = 20);

  -- A confirmed order has no expiry.
  perform pg_temp.as_user(c_customer);
  v_order := (public.place_order('[{"product_id":"mt-num","quantity":1}]'::jsonb) ->> 'id')::uuid;
  perform pg_temp.as_user(c_staff);
  update public.orders set status = 'confirmed' where id = v_order;
  perform pg_temp.check_true('M2h confirmed never expires',
    (select reservation_expires_at from public.orders where id = v_order) is null
    and (select expires_at from public.stock_reservations where order_id = v_order) is null);
  update public.orders set status = 'cancelled' where id = v_order;
  raise notice 'M2 ok - 48 hour expiry is atomic, repeat-safe, and never touches confirmed orders';

  -- M3 pre-rollout orders --------------------------------------------------------------
  perform pg_temp.as_postgres();
  insert into public.orders (order_number, profile_id, customer_type_at_purchase, total_cents, status)
  values ('MT-LEGACY-1', c_customer::uuid, 'retail', 100, 'pending') returning id into v_order;
  insert into public.order_items (order_id, product_id, product_name_snapshot, unit_price_cents, quantity, line_total_cents, tier_code_snapshot)
  values (v_order, 'mt-num', 'MT Number', 100, 2, 200, 'retail');
  perform pg_temp.check_true('M3a no retroactive hold', not exists (select 1 from public.stock_reservations where order_id = v_order));
  perform pg_temp.as_user(c_staff);
  update public.orders set status = 'shipped' where id = v_order;
  perform pg_temp.check_true('M3b deducted on first shipment',
    (select stock from public.products where id = 'mt-num') = 18
    and (select stock_state from public.orders where id = v_order) = 'consumed');
  update public.orders set status = 'delivered' where id = v_order;
  perform pg_temp.check_true('M3c not deducted twice', (select stock from public.products where id = 'mt-num') = 18);

  perform pg_temp.as_postgres();
  insert into public.orders (order_number, profile_id, customer_type_at_purchase, total_cents, status)
  values ('MT-LEGACY-2', c_customer::uuid, 'retail', 100, 'processing') returning id into v_order;
  insert into public.order_items (order_id, product_id, product_name_snapshot, unit_price_cents, quantity, line_total_cents, tier_code_snapshot)
  values (v_order, 'mt-num', 'MT Number', 100, 999, 99900, 'retail');
  perform pg_temp.as_user(c_staff);
  update public.orders set status = 'shipped' where id = v_order;
  perform pg_temp.check_true('M3d short stock flags instead of failing',
    (select stock_state from public.orders where id = v_order) = 'needs_reconciliation'
    and exists (select 1 from public.stock_reconciliation_flags f where f.order_id = v_order and f.resolved_at is null)
    and (select stock from public.products where id = 'mt-num') = 18);
  raise notice 'M3 ok - pre-rollout orders deduct once when possible, and flag otherwise';

  -- M4 staff cannot reach money ---------------------------------------------------------
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('M4a unit cost', 'select unit_cost_cents from public.inventory_units limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4b filter on cost', 'select id from public.inventory_units where unit_cost_cents > 0', 'permission denied%');
  perform pg_temp.expect_fail('M4c select all', 'select * from public.grn_lines limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4d GRN total', 'select total_cost_cents from public.grns limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4e PO total', 'select total_cents from public.purchase_orders limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4f PO line cost', 'select unit_cost_cents from public.purchase_order_lines limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4g return value', 'select total_cents from public.supplier_returns limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4h return item cost', 'select unit_cost_cents from public.supplier_return_items limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4i opening balance', 'select opening_balance_cents from public.suppliers limit 1', 'permission denied%');
  perform pg_temp.expect_fail('M4j cost function', $q$select * from public.admin_purchase_costs('unit', '{}')$q$, 'insufficient_privilege:%');
  perform pg_temp.expect_fail('M4k balances', 'select * from public.admin_supplier_balances()', 'insufficient_privilege:%');
  perform pg_temp.expect_fail('M4l statement', 'select * from public.admin_supplier_statement(gen_random_uuid())', 'insufficient_privilege:%');
  perform pg_temp.check_true('M4m payments invisible', (select count(*) from public.supplier_payments) = 0);
  perform pg_temp.check_true('M4n operational columns readable', (select count(*) >= 0 from public.inventory_units));
  perform pg_temp.check_true('M4o stock figures readable', (select count(*) > 0 from public.admin_inventory_dashboard()));
  perform pg_temp.as_user(c_customer);
  perform pg_temp.check_true('M4p customers get no dashboard rows', (select count(*) from public.admin_inventory_dashboard()) = 0);
  perform pg_temp.expect_fail('M4q direct order insert',
    format('insert into public.orders (order_number, profile_id, customer_type_at_purchase) values (%L, %L::uuid, %L)', 'X', c_customer, 'retail'),
    'permission denied%');
  perform pg_temp.as_user(c_admin);
  perform pg_temp.expect_fail('M4r direct tracking change',
    $q$update public.products set tracking_mode = 'unit' where id = 'mt-num'$q$, 'tracking_mode_locked:%');
  raise notice 'M4 ok - money is unreachable for staff through tables, filters and functions';

  -- M5 accepted, rejected and blank costs ---------------------------------------------
  v_sup := (public.admin_save_supplier(null, 'MT Supplier', null, null, null, null, null, null, null, true) ->> 'id')::uuid;
  perform pg_temp.check_true('M5a blank opening balance is not zero',
    (select opening_cents is null from public.admin_supplier_balances() b where b.supplier_id = v_sup));
  v_po := (public.admin_create_purchase_order(v_sup, v_today, null, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'quantity', 10, 'unit_cost_cents', 1000)), gen_random_uuid()) ->> 'id')::uuid;
  perform pg_temp.expect_fail('M5b rejection needs a reason',
    format('select public.admin_receive_goods(%L, %L::uuid, null, %L::uuid, null, false, null, %L::date, null, %L::jsonb, gen_random_uuid())',
      'supplier', v_sup, v_po, v_today,
      jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'received_quantity', 5, 'rejected_quantity', 2, 'unit_cost_cents', 1000))),
    'rejection_reason_required:%');
  perform pg_temp.expect_fail('M5c cost differing from the PO needs a note',
    format('select public.admin_receive_goods(%L, %L::uuid, null, %L::uuid, null, false, null, %L::date, null, %L::jsonb, gen_random_uuid())',
      'supplier', v_sup, v_po, v_today,
      jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'received_quantity', 5, 'unit_cost_cents', 1200))),
    'cost_discrepancy_note_required:%');
  v_grn := public.admin_receive_goods('supplier', v_sup, null, v_po, 'MT-INV', false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'received_quantity', 5, 'rejected_quantity', 2,
                                         'rejection_reason', 'cracked', 'unit_cost_cents', 1000)), gen_random_uuid());
  perform pg_temp.check_true('M5d only accepted enter stock', (select stock from public.products where id = 'mt-num') = 21);
  perform pg_temp.check_true('M5e only accepted count on the PO',
    (select received_quantity from public.purchase_order_lines where purchase_order_id = v_po) = 3
    and (select rejected_quantity from public.purchase_order_lines where purchase_order_id = v_po) = 2);
  perform pg_temp.check_true('M5f only accepted are owed',
    (select balance_cents from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 3000);

  -- A pending cost stays out of what is owed, and is counted.
  v_grn := public.admin_receive_goods('supplier', v_sup, null, null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'received_quantity', 1, 'cost_pending', true)), gen_random_uuid());
  perform pg_temp.check_true('M5g pending cost',
    (select balance_cents from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 3000
    and (select pending_cost_lines from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 1);
  select l.id into v_line from public.grn_lines l where l.grn_id = (v_grn ->> 'id')::uuid;
  perform public.admin_set_grn_line_cost(v_line, 700, 'invoice arrived');
  perform pg_temp.check_true('M5h cost stated',
    (select balance_cents from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 3700
    and (select pending_cost_lines from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 0);
  raise notice 'M5 ok - accepted, rejected and pending costs reconcile with stock, the PO and what is owed';

  -- M6 correction undoes stock, PO and debt ---------------------------------------------
  select l.id into v_line from public.grn_lines l
   join public.grns g on g.id = l.grn_id where g.supplier_invoice = 'MT-INV';
  v_req := gen_random_uuid();
  perform public.admin_correct_grn_line(v_line, null, 1, 'one was never here', v_req);
  perform public.admin_correct_grn_line(v_line, null, 1, 'one was never here', v_req);
  perform pg_temp.check_true('M6a applied once, everywhere',
    (select stock from public.products where id = 'mt-num') = 21
    and (select received_quantity from public.purchase_order_lines where purchase_order_id = v_po) = 2
    and (select balance_cents from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 2700);
  raise notice 'M6 ok - a GRN correction reconciles stock, the PO and what is owed, once';

  -- M7 IMEI lifecycle ---------------------------------------------------------------------
  v_grn := public.admin_receive_goods('opening', null, null, null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-unit', 'received_quantity', 2, 'unit_cost_cents', 1000,
                                         'serials', jsonb_build_array('MTSERIAL0001', 'MTSERIAL0002'))), gen_random_uuid());
  select id into v_id from public.inventory_units where serial_number = 'MTSERIAL0001';
  perform pg_temp.expect_fail('M7a same serial while in the shop',
    format('select public.admin_receive_goods(%L, null, null, null, null, false, null, %L::date, null, %L::jsonb, gen_random_uuid())',
      'opening', v_today, jsonb_build_array(jsonb_build_object('product_id', 'mt-unit', 'received_quantity', 1, 'unit_cost_cents', 1000,
        'serials', jsonb_build_array('MTSERIAL0001')))),
    'duplicate_serial:%');
  perform public.admin_write_off_units(array[v_id], 'correction', 'wrong item entered');
  perform pg_temp.expect_fail('M7b re-entry needs a reason',
    format('select public.admin_receive_goods(%L, null, null, null, null, false, null, %L::date, null, %L::jsonb, gen_random_uuid())',
      'opening', v_today, jsonb_build_array(jsonb_build_object('product_id', 'mt-unit', 'received_quantity', 1, 'unit_cost_cents', 1000,
        'serials', jsonb_build_array('MTSERIAL0001')))),
    'serial_previously_recorded:%');
  perform public.admin_receive_goods('buyback', null, 'A customer', null, null, false, null, v_today, null,
    jsonb_build_array(jsonb_build_object('product_id', 'mt-unit', 'received_quantity', 1, 'unit_cost_cents', 800,
      'serials', jsonb_build_array('MTSERIAL0001'), 'serial_reentry_reason', 'bought back')), gen_random_uuid());
  perform pg_temp.check_true('M7c history kept, one active unit',
    (select count(*) from public.inventory_units where serial_number = 'MTSERIAL0001') = 2
    and (select count(*) from public.inventory_units where serial_number = 'MTSERIAL0001' and status = 'in_stock') = 1
    and (select reentry_of_unit_id from public.inventory_units where serial_number = 'MTSERIAL0001' and status = 'in_stock') = v_id);
  raise notice 'M7 ok - an IMEI can legitimately return, never twice at once, and history stays';

  -- M8 discount approval is bound to one bill ----------------------------------------------
  perform pg_temp.as_user(c_staff);
  v_req := gen_random_uuid();
  v_items := jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'variant_id', null, 'quantity', 1));
  perform pg_temp.expect_fail('M8a over the limit',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 1000, null, null, null, null, null, %L::uuid)', v_items, 'cash', v_req),
    'discount_approval_required:%');
  v_approval := (public.pos_request_discount_approval(v_req, v_items, null, 1000, 'loyal customer') ->> 'id')::uuid;
  perform pg_temp.expect_fail('M8b staff cannot approve',
    format('select public.admin_decide_discount_approval(%L::uuid, true, null)', v_approval), 'insufficient_privilege:%');
  perform pg_temp.expect_fail('M8c not approved yet',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 1000, null, null, null, null, %L::uuid, %L::uuid)', v_items, 'cash', v_approval, v_req),
    'discount_approval_required:%');
  perform pg_temp.as_user(c_admin);
  perform public.admin_decide_discount_approval(v_approval, true, null);
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('M8d not more than approved',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 2000, null, null, null, null, %L::uuid, %L::uuid)', v_items, 'cash', v_approval, v_req),
    'discount_approval_required:%');
  v_res := public.pos_create_sale(v_items, 'cash', null, 1000, null, null, null, null, v_approval, v_req);
  perform pg_temp.check_true('M8e sold with the approved discount',
    (v_res ->> 'total_cents')::bigint = 199000
    and (select status from public.pos_discount_approvals where id = v_approval) = 'used');
  perform pg_temp.check_true('M8f stock fell once', (select stock from public.products where id = 'mt-num') = 20);
  perform pg_temp.expect_fail('M8g an approval is used once',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 1000, null, null, null, null, %L::uuid, gen_random_uuid())', v_items, 'cash', v_approval),
    'discount_approval_required:%');
  raise notice 'M8 ok - discounts above the limit need an approval, for that bill, once';

  -- M9 wholesale at the counter, quantity return, quarantine lot, refund --------------------
  -- This suite is one transaction, and the P1 ledger index refuses a repeat of the
  -- same transition within a transaction (real requests are separate ones). Jumping
  -- the number as the operator keeps later transitions from repeating earlier ones.
  -- The profile guard reads the JWT, so the admin's claims stay set for this update.
  perform pg_temp.as_user(c_admin);
  perform pg_temp.as_postgres();
  update public.products set stock = stock + 1000 where id = 'mt-num';
  update public.profiles set customer_type = 'wholesale_vip' where id = c_customer::uuid;
  perform pg_temp.as_user(c_admin);
  v_res := public.pos_create_sale(jsonb_build_array(jsonb_build_object('product_id', 'mt-num', 'quantity', 2)), 'card', null, 0,
                                  null, null, c_customer::uuid, null, null, gen_random_uuid());
  perform pg_temp.check_true('M9a wholesale price for that account', (v_res ->> 'total_cents')::bigint = 300000);
  perform pg_temp.check_true('M9b stock', (select stock from public.products where id = 'mt-num') = 1018);
  v_item := (select id from public.pos_sale_items where pos_sale_id = (v_res ->> 'id')::uuid);
  v_req := gen_random_uuid();
  v_items := jsonb_build_array(jsonb_build_object('line_id', v_item, 'quantity', 1, 'condition', 'opened'));
  v_ret := (public.admin_record_customer_return('pos', (v_res ->> 'id')::uuid, v_items, null, v_req) ->> 'id')::uuid;
  perform public.admin_record_customer_return('pos', (v_res ->> 'id')::uuid, v_items, null, v_req);
  perform pg_temp.check_true('M9c return replayed once, stock unmoved',
    (select returned_quantity from public.pos_sale_items where id = v_item) = 1
    and (select stock from public.products where id = 'mt-num') = 1018);
  perform pg_temp.check_true('M9d quarantined, not available',
    (select quarantined from public.admin_inventory_dashboard() d where d.product_id = 'mt-num') = 1);
  perform pg_temp.expect_fail('M9e cannot return more than sold',
    format('select public.admin_record_customer_return(%L, %L::uuid, %L::jsonb, null, gen_random_uuid())', 'pos', v_res ->> 'id',
           jsonb_build_array(jsonb_build_object('line_id', v_item, 'quantity', 2, 'condition', 'opened'))),
    'already_returned:%');
  select id into v_lot from public.quarantine_lots where customer_return_id = v_ret;
  perform pg_temp.expect_fail('M9f stale decision',
    format('select public.admin_resolve_quarantine_lot(%L::uuid, 9, 1, 0, %L)', v_lot, 'checked'), 'stale_quantity:%');
  perform public.admin_resolve_quarantine_lot(v_lot, 1, 1, 0, 'checked, sealed');
  perform pg_temp.check_true('M9g released back to stock', (select stock from public.products where id = 'mt-num') = 1019);
  raise notice 'M9 ok - counter wholesale price, return to quarantine, explicit release';

  -- M10 supplier return reversal -------------------------------------------------------------
  perform pg_temp.as_postgres();
  update public.products set stock = stock + 1000 where id = 'mt-num';
  perform pg_temp.as_user(c_admin);
  select l.id into v_line from public.grn_lines l join public.grns g on g.id = l.grn_id where g.supplier_invoice = 'MT-INV';
  v_res := public.admin_create_supplier_return(v_sup, v_today, 'credit', null,
    jsonb_build_array(jsonb_build_object('grn_line_id', v_line, 'quantity', 1)), 'faulty', gen_random_uuid());
  perform pg_temp.check_true('M10a credit reduces what is owed',
    (select balance_cents from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 1700
    and (select stock from public.products where id = 'mt-num') = 2018);
  perform public.admin_reverse_supplier_return((v_res ->> 'id')::uuid, 'entered by mistake');
  perform pg_temp.check_true('M10b reversal restores both',
    (select balance_cents from public.admin_supplier_balances() b where b.supplier_id = v_sup) = 2700
    and (select stock from public.products where id = 'mt-num') = 2019);
  perform pg_temp.expect_fail('M10c reversed once',
    format('select public.admin_reverse_supplier_return(%L::uuid, %L)', v_res ->> 'id', 'again'), 'return_reversed:%');
  raise notice 'M10 ok - a supplier return can be reversed, once';

  -- M11 customer limits are configurable and start blank ---------------------------------------
  perform pg_temp.check_true('M11a no limit by default',
    (select max_reserved_units_per_customer is null and max_active_orders_per_customer is null and staff_max_discount_bps = 0
       from public.inventory_policy));
  perform public.admin_save_inventory_policy(2, null, 0, 'test limit');
  perform pg_temp.as_user(c_customer);
  perform pg_temp.expect_fail('M11b limit enforced',
    $q$select public.place_order('[{"product_id":"mt-num","quantity":3}]'::jsonb)$q$, 'reservation_limit_reached:%');
  raise notice 'M11 ok - the limit is enforced once configured';
end $$;

rollback;

do $$ begin raise notice 'ALL INVENTORY MASTER CHECKS PASSED'; end $$;
