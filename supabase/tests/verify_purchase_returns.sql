-- ============================================================================
-- Apple Expert - suppliers, purchase orders, supplier returns and payments
-- ----------------------------------------------------------------------------
-- Updated for 20261101110000 and 20261101130000. NOT YET EXECUTED against them.
-- Run AFTER all migrations and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_purchase_returns.sql
--
-- Like verify_grn_units_pos.sql, the checks run through the real API login
-- (authenticator -> role authenticated), so every function runs as a
-- NON-operator session and the stock guard is fully armed. Fixtures are
-- committed and removed at the start of every run; the checks run in one
-- transaction that is rolled back.
-- A clean run ends with "ALL PURCHASE & RETURNS CHECKS PASSED".
-- ============================================================================

\set ON_ERROR_STOP on

begin;
delete from public.inventory_movements where product_id like 'pt-%';
delete from public.supplier_return_items where product_id like 'pt-%';
delete from public.supplier_payment_allocations where grn_id in (select id from public.grns where supplier_name like 'PT %');
update public.inventory_units set supplier_return_id = null where product_id like 'pt-%';
delete from public.supplier_returns where supplier_id in (select id from public.suppliers where name like 'PT %');
delete from public.supplier_payments where supplier_id in (select id from public.suppliers where name like 'PT %');
delete from public.inventory_units where product_id like 'pt-%';
delete from public.grn_lines where product_id like 'pt-%';
delete from public.grns where supplier_name like 'PT %';
delete from public.purchase_order_lines where product_id like 'pt-%';
delete from public.purchase_orders where supplier_id in (select id from public.suppliers where name like 'PT %');
delete from public.suppliers where name like 'PT %';
update public.products set stock = 0 where id like 'pt-%';
delete from public.product_prices where product_id like 'pt-%';
delete from public.product_variants where product_id like 'pt-%';
delete from public.products where id like 'pt-%';
delete from auth.users where id in ('81111111-1111-1111-1111-111111111111',
                                    '82222222-2222-2222-2222-222222222222',
                                    '83333333-3333-3333-3333-333333333333');
commit;

begin;
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '',
       now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false
from (values
  ('81111111-1111-1111-1111-111111111111', 'pt-admin@test.local'),
  ('82222222-2222-2222-2222-222222222222', 'pt-staff@test.local'),
  ('83333333-3333-3333-3333-333333333333', 'pt-customer@test.local')
) as u(id, email);

insert into public.user_roles (profile_id, role) values
  ('81111111-1111-1111-1111-111111111111', 'admin'),
  ('82222222-2222-2222-2222-222222222222', 'staff');

insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode) values
  ('pt-pad',  'PT Pad',  (select id from public.categories where slug = 'accessories'), 'Other Accessories', 0, true, 'unit'),
  ('pt-case', 'PT Case', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 0, true, 'unit');

insert into public.product_variants (id, product_id, legacy_key, name, stock) values
  ('8a000000-0000-0000-0000-00000000000a', 'pt-pad', 'v1', 'Blue 128GB', null),
  ('8b000000-0000-0000-0000-00000000000b', 'pt-pad', 'v2', 'Grey 256GB', null);

insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty, starts_at) values
  ('pt-pad',  '8a000000-0000-0000-0000-00000000000a', 'retail', 15000000, 1, now() - interval '1 day'),
  ('pt-case', null,                                   'retail',   300000, 1, now() - interval '1 day');
commit;


\connect "host=127.0.0.1 dbname=postgres user=authenticator"

begin;
set local role authenticated;

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

create function pg_temp.receive(p_supplier uuid, p_po uuid, p_invoice text, p_on date, p_lines jsonb, p_req uuid default gen_random_uuid()) returns jsonb language sql as $$
  select public.admin_receive_goods('supplier', p_supplier, null, p_po, p_invoice, false, null, p_on, null, p_lines, p_req) $$;

create function pg_temp.line(p_product text, p_variant uuid, p_qty integer, p_cost bigint) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('product_id', p_product, 'variant_id', p_variant, 'received_quantity', p_qty, 'unit_cost_cents', p_cost)) $$;

do $$
declare
  c_admin    constant text := '81111111-1111-1111-1111-111111111111';
  c_staff    constant text := '82222222-2222-2222-2222-222222222222';
  c_customer constant text := '83333333-3333-3333-3333-333333333333';
  c_va       constant uuid := '8a000000-0000-0000-0000-00000000000a';
  c_vb       constant uuid := '8b000000-0000-0000-0000-00000000000b';
  v_today    date := (now() at time zone 'Asia/Colombo')::date;
  v_res      jsonb;
  v_sup_a    uuid;
  v_sup_b    uuid;
  v_po       uuid;
  v_po2      uuid;
  v_req      uuid;
  v_n        integer;
  v_codes    text[];
  v_bal      record;
  v_pay      uuid;
  v_grn_b    uuid;
  v_lines    jsonb;
begin
  if session_user <> 'authenticator' or pg_has_role(session_user, 'postgres', 'MEMBER') then
    raise exception 'P0 FAILED - not running as the API would (session %)', session_user;
  end if;

  -- P1 roles ---------------------------------------------------------------
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('P1a staff supplier',
    $q$select public.admin_save_supplier(null, 'PT Staffco', null, null, null, null, null, null, null, true)$q$,
    'insufficient_privilege:%');
  perform pg_temp.expect_fail('P1b staff balances',
    'select * from public.admin_supplier_balances()', 'insufficient_privilege:%');
  perform pg_temp.expect_fail('P1c staff payment',
    format('select public.admin_record_supplier_payment(gen_random_uuid(), %L::date, 100, ''cash'', null, null, null, gen_random_uuid())', v_today),
    'insufficient_privilege:%');
  perform pg_temp.as_user(c_customer);
  perform pg_temp.expect_fail('P1d customer PO',
    format('select public.admin_create_purchase_order(gen_random_uuid(), %L::date, null, null, ''[]''::jsonb, gen_random_uuid())', v_today),
    'insufficient_privilege:%');
  perform pg_temp.expect_fail('P1e customer direct insert',
    $q$insert into public.suppliers (supplier_code, name) values ('X', 'PT Direct')$q$,
    'permission denied%');
  raise notice 'P1 ok - staff and customers cannot write; staff cannot see balances';

  -- P2 suppliers -----------------------------------------------------------
  perform pg_temp.as_user(c_admin);
  v_res := public.admin_save_supplier(null, 'PT Alpha Traders', 'Rizwan', '077 123 4567', 'Sales@Alpha.lk',
                                      'Main St, Kinniya', null, 1000000, 'agreed with supplier', true);
  v_sup_a := (v_res ->> 'id')::uuid;
  if v_res ->> 'supplier_code' !~ '^SUP-[0-9]{4,}$' then
    raise exception 'P2a FAILED - supplier code %', v_res ->> 'supplier_code';
  end if;
  v_sup_b := (public.admin_save_supplier(null, 'PT Beta Imports', null, null, null, null, null, null, null, true) ->> 'id')::uuid;
  perform pg_temp.expect_fail('P2b duplicate name',
    $q$select public.admin_save_supplier(null, '  pt alpha traders ', null, null, null, null, null, null, null, true)$q$,
    'duplicate_supplier:%');
  perform pg_temp.expect_fail('P2c bad email',
    $q$select public.admin_save_supplier(null, 'PT Gamma', null, null, 'not-an-email', null, null, null, null, true)$q$,
    'invalid_email:%');
  perform public.admin_save_supplier(v_sup_a, 'PT Alpha Traders', 'Rizwan M', '077 123 4567', 'sales@alpha.lk',
                                     'Main St, Kinniya', 'Pays in 30 days', 1000000, null, true);
  if (select contact_person from public.suppliers where id = v_sup_a) <> 'Rizwan M'
     or (select email from public.suppliers where id = v_sup_a) <> 'sales@alpha.lk' then
    raise exception 'P2d FAILED - update not saved';
  end if;
  perform pg_temp.as_user(c_staff);
  if (select count(*) from public.suppliers where name like 'PT %') <> 2 then
    raise exception 'P2e FAILED - staff cannot read suppliers';
  end if;
  perform pg_temp.as_user(c_customer);
  if (select count(*) from public.suppliers) <> 0 then
    raise exception 'P2f FAILED - a customer can read suppliers';
  end if;
  raise notice 'P2 ok - suppliers created and updated, duplicates and bad email refused, staff read only';

  -- P3 purchase order ------------------------------------------------------
  perform pg_temp.as_user(c_admin);
  perform pg_temp.expect_fail('P3a variant required',
    format('select public.admin_create_purchase_order(%L, %L::date, null, null, %L::jsonb, gen_random_uuid())',
           v_sup_a, v_today, jsonb_build_array(jsonb_build_object('product_id', 'pt-pad', 'quantity', 2, 'unit_cost_cents', 100))),
    'variant_required:%');
  v_req := gen_random_uuid();
  v_lines := jsonb_build_array(
    jsonb_build_object('product_id', 'pt-pad', 'variant_id', c_va, 'quantity', 3, 'unit_cost_cents', 12000000),
    jsonb_build_object('product_id', 'pt-case', 'quantity', 5, 'unit_cost_cents', 150000));
  v_res := public.admin_create_purchase_order(v_sup_a, v_today, v_today + 7, 'First order', v_lines, v_req);
  v_po := (v_res ->> 'id')::uuid;
  if (public.admin_create_purchase_order(v_sup_a, v_today, v_today + 7, 'First order', v_lines, v_req) ->> 'id')::uuid <> v_po then
    raise exception 'P3b FAILED - replay created a second PO';
  end if;
  -- Money is read through the checked function: the column is not granted.
  if (select cents from public.admin_purchase_costs('po', array[v_po])) <> 3 * 12000000 + 5 * 150000
     or (select status from public.purchase_orders where id = v_po) <> 'open'
     or (select count(*) from public.purchase_order_lines where purchase_order_id = v_po) <> 2 then
    raise exception 'P3c FAILED - PO totals or lines wrong';
  end if;
  raise notice 'P3 ok - PO created with lines and total, replay safe, variant required';

  -- P4 receive against the PO, one line partly rejected -------------------------
  v_res := pg_temp.receive(v_sup_a, v_po, 'INV-1', v_today,
    jsonb_build_array(
      pg_temp.line('pt-pad', c_va, 2, 12000000),
      pg_temp.line('pt-case', null, 5, 150000)));
  if (select supplier_id from public.grns where id = (v_res ->> 'id')::uuid) <> v_sup_a
     or (select purchase_order_id from public.grns where id = (v_res ->> 'id')::uuid) <> v_po then
    raise exception 'P4a FAILED - GRN not linked to supplier / PO';
  end if;
  if (select status from public.purchase_orders where id = v_po) <> 'partially_received'
     or (select received_quantity from public.purchase_order_lines where purchase_order_id = v_po and product_id = 'pt-pad') <> 2
     or (select received_quantity from public.purchase_order_lines where purchase_order_id = v_po and product_id = 'pt-case') <> 5 then
    raise exception 'P4b FAILED - PO not counted';
  end if;
  if (select stock from public.products where id = 'pt-pad') <> 2 or (select stock from public.products where id = 'pt-case') <> 5 then
    raise exception 'P4c FAILED - stock not raised';
  end if;
  -- The same invoice again is a possible duplicate, until a person confirms it.
  perform pg_temp.expect_fail('P4d possible duplicate delivery',
    format('select pg_temp.receive(%L, null, %L, %L::date, %L::jsonb)', v_sup_a, ' inv-1 ', v_today,
           jsonb_build_array(pg_temp.line('pt-case', null, 1, 150000))),
    'possible_duplicate_delivery:%');
  -- Another supplier's invoice with the same number is unrelated.
  perform pg_temp.receive(v_sup_b, null, 'INV-1', v_today, jsonb_build_array(pg_temp.line('pt-case', null, 1, 140000)));
  raise notice 'P4 ok - goods received against the PO: GRN linked, PO counted, stock raised, duplicates caught per supplier';

  -- P5 over-receiving is refused and changes nothing -------------------------
  select count(*) into v_n from public.grns where supplier_name like 'PT %';
  perform pg_temp.expect_fail('P5a over receive',
    format('select pg_temp.receive(%L, %L, null, %L::date, %L::jsonb)',
           v_sup_a, v_po, v_today,
           jsonb_build_array(pg_temp.line('pt-pad', c_va, 2, 12000000))),
    'exceeds_purchase_order:%');
  perform pg_temp.expect_fail('P5b item not on PO',
    format('select pg_temp.receive(%L, %L, null, %L::date, %L::jsonb)',
           v_sup_a, v_po, v_today,
           jsonb_build_array(pg_temp.line('pt-pad', c_vb, 1, 12000000))),
    'exceeds_purchase_order:%');
  if (select count(*) from public.grns where supplier_name like 'PT %') <> v_n
     or (select stock from public.products where id = 'pt-pad') <> 2
     or (select received_quantity from public.purchase_order_lines where purchase_order_id = v_po and product_id = 'pt-pad') <> 2 then
    raise exception 'P5c FAILED - a refused receipt left something behind';
  end if;
  perform pg_temp.expect_fail('P5d PO from other supplier',
    format('select pg_temp.receive(%L, %L, null, %L::date, %L::jsonb)',
           v_sup_b, v_po, v_today,
           jsonb_build_array(pg_temp.line('pt-case', null, 1, 150000))),
    'purchase_order_mismatch:%');
  raise notice 'P5 ok - receiving more than ordered, or another supplier''s PO, is refused atomically';

  -- P6 receive without a PO, from supplier B ---------------------------------
  v_res := pg_temp.receive(v_sup_b, null, null, v_today, jsonb_build_array(pg_temp.line('pt-case', null, 2, 140000)));
  v_grn_b := (v_res ->> 'id')::uuid;
  -- 5 against the PO, 1 from supplier B in P4, 2 here.
  if (select stock from public.products where id = 'pt-case') <> 8 then
    raise exception 'P6 FAILED - stock after supplier B GRN';
  end if;
  raise notice 'P6 ok - GRN without a PO for another supplier';

  -- P7 closing POs -------------------------------------------------------------
  perform public.admin_close_purchase_order(v_po, 'Supplier is out of stock');
  if (select status from public.purchase_orders where id = v_po) <> 'closed' then
    raise exception 'P7a FAILED - partly received PO not closed';
  end if;
  perform pg_temp.expect_fail('P7b close twice',
    format('select public.admin_close_purchase_order(%L, ''again'')', v_po), 'purchase_order_finished:%');
  perform pg_temp.expect_fail('P7c receive on closed',
    format('select pg_temp.receive(%L, %L, null, %L::date, %L::jsonb)',
           v_sup_a, v_po, v_today,
           jsonb_build_array(pg_temp.line('pt-pad', c_va, 1, 12000000))),
    'purchase_order_finished:%');
  v_po2 := (public.admin_create_purchase_order(v_sup_a, v_today, null, null,
              jsonb_build_array(jsonb_build_object('product_id', 'pt-case', 'quantity', 1, 'cost_pending', true)), gen_random_uuid()) ->> 'id')::uuid;
  perform public.admin_close_purchase_order(v_po2, 'Ordered by mistake');
  if (select status from public.purchase_orders where id = v_po2) <> 'cancelled' then
    raise exception 'P7d FAILED - untouched PO not cancelled';
  end if;
  raise notice 'P7 ok - partly received PO closes, untouched PO cancels, finished POs refuse receipts';

  -- P8 supplier returns ---------------------------------------------------------
  select array_agg(barcode order by fifo_seq) into v_codes
    from public.inventory_units u join public.grns g on g.id = u.grn_id
   where u.product_id = 'pt-case' and g.supplier_id = v_sup_a;
  perform pg_temp.expect_fail('P8a wrong supplier',
    format('select public.admin_create_supplier_return(%L, %L::date, ''credit'', %L::text[], null, null, gen_random_uuid())',
           v_sup_b, v_today, array[v_codes[1]]),
    'wrong_supplier:%');
  perform pg_temp.expect_fail('P8b duplicate scan',
    format('select public.admin_create_supplier_return(%L, %L::date, ''credit'', %L::text[], null, null, gen_random_uuid())',
           v_sup_a, v_today, array[v_codes[1], lower(v_codes[1])]),
    'duplicate_item:%');
  v_req := gen_random_uuid();
  v_res := public.admin_create_supplier_return(v_sup_a, v_today, 'credit', array[v_codes[1], v_codes[2]], null, 'Cracked', v_req);
  if (v_res ->> 'total_cents')::bigint <> 300000 or (v_res ->> 'total_units')::integer <> 2 then
    raise exception 'P8c FAILED - return totals %', v_res;
  end if;
  if (public.admin_create_supplier_return(v_sup_a, v_today, 'credit', array[v_codes[1], v_codes[2]], null, 'Cracked', v_req) ->> 'id')
     <> v_res ->> 'id' then
    raise exception 'P8d FAILED - replay created a second return';
  end if;
  if (select stock from public.products where id = 'pt-case') <> 6
     or (select count(*) from public.inventory_units where barcode = any (v_codes[1:2]) and status = 'returned_to_supplier') <> 2 then
    raise exception 'P8e FAILED - stock or unit status after return';
  end if;
  perform pg_temp.expect_fail('P8f return again',
    format('select public.admin_create_supplier_return(%L, %L::date, ''cash'', %L::text[], null, null, gen_random_uuid())',
           v_sup_a, v_today, array[v_codes[1]]),
    'unit_not_available:%');
  perform public.admin_create_supplier_return(v_sup_a, v_today, 'cash', array[v_codes[3]], null, null, gen_random_uuid());
  raise notice 'P8 ok - units go back to the right supplier only, once; stock falls; replay safe';

  -- P9 payments and balance -------------------------------------------------------
  perform pg_temp.expect_fail('P9a cheque needs number',
    format('select public.admin_record_supplier_payment(%L, %L::date, 100000, ''cheque'', null, null, null, gen_random_uuid())', v_sup_a, v_today),
    'reference_required:%');
  perform pg_temp.expect_fail('P9b zero amount',
    format('select public.admin_record_supplier_payment(%L, %L::date, 0, ''cash'', null, null, null, gen_random_uuid())', v_sup_a, v_today),
    'invalid_amount:%');
  perform public.admin_record_supplier_payment(v_sup_a, v_today, 10000000, 'bank_transfer', 'TRX-1', null, null, gen_random_uuid());
  v_pay := (public.admin_record_supplier_payment(v_sup_a, v_today, 500000, 'cheque', 'CHQ-77', null, null, gen_random_uuid()) ->> 'id')::uuid;
  perform public.admin_void_supplier_payment(v_pay, 'Cheque bounced');
  perform pg_temp.expect_fail('P9c void twice',
    format('select public.admin_void_supplier_payment(%L, ''again'')', v_pay), 'payment_voided:%');

  select * into v_bal from public.admin_supplier_balances() b where b.supplier_id = v_sup_a;
  -- opening 1,000,000 + GRN (2 x 12,000,000 + 5 x 150,000) - credit return 300,000 - payment 10,000,000
  if v_bal.purchases_cents <> 24750000 or v_bal.credit_returns_cents <> 300000 or v_bal.cash_returns_cents <> 150000
     or v_bal.payments_cents <> 10000000 or v_bal.balance_cents <> 1000000 + 24750000 - 300000 - 10000000 then
    raise exception 'P9d FAILED - balance %', row_to_json(v_bal);
  end if;
  perform pg_temp.as_user(c_staff);
  if (select count(*) from public.supplier_payments) <> 0 then
    raise exception 'P9e FAILED - staff can read supplier payments';
  end if;
  raise notice 'P9 ok - payments recorded and voided; balance = opening + GRNs - credit returns - payments';

  -- P10 the ledger still agrees with the shelf ------------------------------------
  perform pg_temp.as_user(c_admin);
  if (select stock from public.products where id = 'pt-case')
       <> (select count(*) from public.inventory_units where product_id = 'pt-case' and status in ('in_stock', 'reserved'))
     or (select stock from public.products where id = 'pt-case')
       <> (select sum(delta) from public.inventory_movements where product_id = 'pt-case') then
    raise exception 'P10 FAILED - stock, shelf units and ledger disagree';
  end if;
  raise notice 'P10 ok - stock = units on the shelf = sum of the ledger';

  raise notice 'ALL PURCHASE & RETURNS CHECKS PASSED';
end
$$;

rollback;

\connect "dbname=postgres user=postgres"

-- Remove the committed fixtures, so test products never linger on the local shop.
begin;
update public.products set stock = 0 where id like 'pt-%';
delete from public.product_prices where product_id like 'pt-%';
delete from public.product_variants where product_id like 'pt-%';
delete from public.products where id like 'pt-%';
delete from auth.users where id in ('81111111-1111-1111-1111-111111111111',
                                    '82222222-2222-2222-2222-222222222222',
                                    '83333333-3333-3333-3333-333333333333');
commit;
