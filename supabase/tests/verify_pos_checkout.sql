-- ============================================================================
-- Apple Expert - counter checkout verification (migration 20261101150000)
-- ----------------------------------------------------------------------------
-- LOCAL ONLY. Run after all migrations and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_pos_checkout.sql
--
-- One transaction, rolled back. Parallel behaviour is in
-- verify_pos_checkout_concurrency.sh. A clean run ends with
-- "ALL POS CHECKOUT CHECKS PASSED".
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
-- The structured detail of a price_changed refusal.
create function pg_temp.changes_from(p_sql text) returns jsonb language plpgsql as $$
declare
  v_detail text;
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm not like 'price_changed:%' then
      raise exception 'expected price_changed, got: %', sqlerrm;
    end if;
    get stacked diagnostics v_detail = pg_exception_detail;
    return v_detail::jsonb;
  end;
  raise exception 'expected price_changed, the statement succeeded: %', p_sql;
end $$;
create function pg_temp.checkout(p_items jsonb, p_expected jsonb, p_request uuid, p_customer uuid default null,
                                 p_discount bigint default 0, p_approval uuid default null) returns jsonb language sql as $$
  select public.pos_checkout(p_items, 'cash', null, p_discount, null, null, p_customer, 'test', p_approval, p_request, p_expected)
$$;
create function pg_temp.checkout_sql(p_items jsonb, p_expected jsonb, p_request uuid, p_customer uuid default null) returns text language sql as $$
  select format('select pg_temp.checkout(%L::jsonb, %L::jsonb, %L::uuid, %L::uuid)', p_items, p_expected, p_request, p_customer)
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '', now(), now(), now(),
       '{}'::jsonb, '{}'::jsonb, false
from (values ('51111111-1111-1111-1111-111111111111', 'db-admin@test.local'),
             ('52222222-2222-2222-2222-222222222222', 'db-staff@test.local'),
             ('53333333-3333-3333-3333-333333333333', 'db-vip@test.local'),
             ('54444444-4444-4444-4444-444444444444', 'db-customer@test.local')) as u(id, email);

insert into public.user_roles (profile_id, role) values
  ('51111111-1111-1111-1111-111111111111', 'admin'),
  ('52222222-2222-2222-2222-222222222222', 'staff');
update public.profiles set customer_type = 'wholesale_vip' where id = '53333333-3333-3333-3333-333333333333';

insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode) values
  ('db-a', 'DB Cable', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 50, true, 'quantity'),
  ('db-v', 'DB Case',  (select id from public.categories where slug = 'accessories'), 'Other Accessories', 50, true, 'quantity'),
  ('db-u', 'DB Watch', (select id from public.categories where slug = 'watch'), 'Devices', 0, true, 'unit');
insert into public.product_variants (id, product_id, legacy_key, name, stock) values
  ('5a000000-0000-0000-0000-00000000000a', 'db-v', 'a', 'Blue', null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty, starts_at) values
  ('db-a', null, 'retail', 100000, 1, now() - interval '1 day'),
  ('db-a', null, 'wholesale_vip', 80000, 1, now() - interval '1 day'),
  ('db-v', '5a000000-0000-0000-0000-00000000000a', 'retail', 50000, 1, now() - interval '1 day'),
  ('db-u', null, 'retail', 900000, 1, now() - interval '1 day');

do $$
declare
  c_admin constant text := '51111111-1111-1111-1111-111111111111';
  c_staff constant text := '52222222-2222-2222-2222-222222222222';
  c_vip   constant uuid := '53333333-3333-3333-3333-333333333333';
  c_cust  constant text := '54444444-4444-4444-4444-444444444444';
  c_blue  constant uuid := '5a000000-0000-0000-0000-00000000000a';
  c_a     constant jsonb := '[{"product_id":"db-a","variant_id":null,"quantity":2}]';
  v_ok    jsonb := '[{"price_cents":100000,"tier_code":"retail"}]';
  v_req   uuid := gen_random_uuid();
  v_res   jsonb;
  v_ch    jsonb;
  v_sales bigint;
  v_moves bigint;
  v_stock integer;
  v_sup   uuid;
  v_code  text;
  v_appr  uuid;
begin
  -- K1 who may call it ----------------------------------------------------------------
  perform pg_temp.as_anon();
  perform pg_temp.expect_fail('K1a anon checkout', pg_temp.checkout_sql(c_a, v_ok, v_req), 'permission denied%');
  perform pg_temp.expect_fail('K1b anon price check', format('select public.pos_check_prices(%L::jsonb, %L::jsonb, null)', c_a, v_ok), 'permission denied%');
  perform pg_temp.as_user(c_cust);
  perform pg_temp.expect_fail('K1c customer checkout', pg_temp.checkout_sql(c_a, v_ok, v_req), 'insufficient_privilege:%');
  perform pg_temp.expect_fail('K1d customer price check', format('select public.pos_check_prices(%L::jsonb, %L::jsonb, null)', c_a, v_ok), 'insufficient_privilege:%');
  raise notice 'K1 ok - staff only';

  -- K2 the displayed price is compared, never charged ---------------------------------
  perform pg_temp.as_user(c_staff);
  v_sales := (select count(*) from public.pos_sales);
  v_stock := (select stock from public.products where id = 'db-a');

  perform pg_temp.expect_fail('K2a no prices', pg_temp.checkout_sql(c_a, null, v_req), 'invalid_expected_prices:%');
  perform pg_temp.expect_fail('K2b wrong count', pg_temp.checkout_sql(c_a, '[]', v_req), 'invalid_expected_prices:%');
  perform pg_temp.expect_fail('K2c not a number', pg_temp.checkout_sql(c_a, '[{"price_cents":"x"}]', v_req), 'invalid_expected_prices:%');

  -- A client claiming a low price gets a refusal, not that price.
  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(c_a, '[{"price_cents":1,"tier_code":"retail"}]', v_req));
  perform pg_temp.check_true('K2d low claim refused and reported', (v_ch -> 0 ->> 'current_cents')::bigint = 100000 and (v_ch -> 0 ->> 'previous_cents')::bigint = 1);
  perform pg_temp.check_true('K2e nothing sold', (select count(*) from public.pos_sales) = v_sales and (select stock from public.products where id = 'db-a') = v_stock);
  raise notice 'K2 ok - a client price is never used';

  -- K3 retail price change: structured, nothing sold, and then the new price ------------
  perform pg_temp.as_postgres();
  update public.product_prices set price_cents = 120000 where product_id = 'db-a' and tier_code = 'retail';
  perform pg_temp.as_user(c_staff);
  v_moves := (select count(*) from public.inventory_movements where product_id = 'db-a');

  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(c_a, v_ok, v_req));
  perform pg_temp.check_true('K3a one change', jsonb_array_length(v_ch) = 1);
  perform pg_temp.check_true('K3b item, previous, current, reason',
    v_ch -> 0 ->> 'product_id' = 'db-a' and v_ch -> 0 ->> 'product_name' = 'DB Cable'
    and (v_ch -> 0 ->> 'previous_cents')::bigint = 100000 and (v_ch -> 0 ->> 'current_cents')::bigint = 120000
    and v_ch -> 0 ->> 'reason' = 'price_changed');
  perform pg_temp.check_true('K3c no sale, stock or ledger change',
    (select count(*) from public.pos_sales) = v_sales and (select stock from public.products where id = 'db-a') = v_stock
    and (select count(*) from public.inventory_movements where product_id = 'db-a') = v_moves);
  perform pg_temp.check_true('K3d the read-only check agrees',
    (public.pos_check_prices(c_a, v_ok, null) -> 0 ->> 'current_cents')::bigint = 120000);
  perform pg_temp.check_true('K3e nothing to report at the right price',
    jsonb_array_length(public.pos_check_prices(c_a, '[{"price_cents":120000,"tier_code":"retail"}]', null)) = 0);

  -- Same request id, after the cashier confirmed the new price.
  v_res := pg_temp.checkout(c_a, '[{"price_cents":120000,"tier_code":"retail"}]', v_req);
  perform pg_temp.check_true('K3f charged the confirmed price', (v_res ->> 'total_cents')::bigint = 240000 and not (v_res ->> 'replayed')::boolean);
  perform pg_temp.check_true('K3g through the ledger',
    (select stock from public.products where id = 'db-a') = v_stock - 2
    and (select count(*) from public.inventory_movements where product_id = 'db-a') = v_moves + 1
    and (select sum(delta) from public.inventory_movements where product_id = 'db-a' and reason = 'sale') = -2);
  raise notice 'K3 ok - a retail price change stops the sale and reports it';

  -- K4 changed again after confirming ---------------------------------------------------
  perform pg_temp.as_postgres();
  update public.product_prices set price_cents = 125000 where product_id = 'db-a' and tier_code = 'retail';
  perform pg_temp.as_user(c_staff);
  v_req := gen_random_uuid();
  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(c_a, '[{"price_cents":120000,"tier_code":"retail"}]', v_req));
  perform pg_temp.check_true('K4 revalidated on the confirmed submit', (v_ch -> 0 ->> 'previous_cents')::bigint = 120000 and (v_ch -> 0 ->> 'current_cents')::bigint = 125000);
  raise notice 'K4 ok - a confirmed bill is checked again';

  -- K5 wholesale ---------------------------------------------------------------------------
  perform pg_temp.as_postgres();
  update public.product_prices set price_cents = 85000 where product_id = 'db-a' and tier_code = 'wholesale_vip';
  perform pg_temp.as_user(c_staff);
  v_req := gen_random_uuid();
  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(c_a, '[{"price_cents":80000,"tier_code":"wholesale_vip"}]', v_req, c_vip));
  perform pg_temp.check_true('K5a wholesale change reported',
    (v_ch -> 0 ->> 'current_cents')::bigint = 85000 and v_ch -> 0 ->> 'current_tier' = 'wholesale_vip' and v_ch -> 0 ->> 'reason' = 'price_changed');
  v_res := pg_temp.checkout(c_a, '[{"price_cents":85000,"tier_code":"wholesale_vip"}]', v_req, c_vip);
  perform pg_temp.check_true('K5b wholesale total', (v_res ->> 'total_cents')::bigint = 170000);

  -- The account stopped being wholesale while the bill was open.
  perform pg_temp.as_user(c_admin);
  perform pg_temp.as_postgres();
  update public.profiles set customer_type = 'retail' where id = c_vip;
  perform pg_temp.as_user(c_staff);
  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(c_a, '[{"price_cents":85000,"tier_code":"wholesale_vip"}]', gen_random_uuid(), c_vip));
  perform pg_temp.check_true('K5c a tier change has its own reason', v_ch -> 0 ->> 'reason' = 'tier_changed' and v_ch -> 0 ->> 'current_tier' = 'retail');
  perform pg_temp.as_user(c_admin);
  perform pg_temp.as_postgres();
  update public.profiles set customer_type = 'wholesale_vip' where id = c_vip;
  raise notice 'K5 ok - wholesale prices and tier changes are protected';

  -- K6 variants, removed prices, several at once ---------------------------------------------
  perform pg_temp.as_postgres();
  update public.product_prices set price_cents = 60000 where variant_id = c_blue;
  delete from public.product_prices where product_id = 'db-u';
  perform pg_temp.as_user(c_staff);
  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(
    format('[{"product_id":"db-a","variant_id":null,"quantity":1},{"product_id":"db-v","variant_id":"%s","quantity":1}]', c_blue)::jsonb,
    '[{"price_cents":1,"tier_code":"retail"},{"price_cents":50000,"tier_code":"retail"}]', gen_random_uuid()));
  perform pg_temp.check_true('K6a every changed line is listed', jsonb_array_length(v_ch) = 2);
  perform pg_temp.check_true('K6b the exact variant', (v_ch -> 1 ->> 'variant_id')::uuid = c_blue and v_ch -> 1 ->> 'variant_name' = 'Blue');
  perform pg_temp.as_user(c_admin);
  v_sup := (public.admin_save_supplier(null, 'DB Supplier', null, null, null, null, null, null, null, true) ->> 'id')::uuid;
  perform public.admin_receive_goods('supplier', v_sup, null, null, null, false, null, current_date, null,
    '[{"product_id":"db-u","received_quantity":2,"unit_cost_cents":700,"serials":["DBCHK0001","DBCHK0002"]}]'::jsonb, gen_random_uuid());
  v_code := (select barcode from public.inventory_units where serial_number = 'DBCHK0001');
  perform pg_temp.as_user(c_staff);
  v_ch := pg_temp.changes_from(pg_temp.checkout_sql(jsonb_build_array(jsonb_build_object('code', v_code)), '[{"price_cents":900000,"tier_code":"retail"}]', gen_random_uuid()));
  perform pg_temp.check_true('K6c a removed price, naming the unit',
    v_ch -> 0 ->> 'reason' = 'price_removed' and v_ch -> 0 ->> 'current_cents' is null and v_ch -> 0 ->> 'code' = v_code);
  perform pg_temp.check_true('K6d the unit was not sold', (select status from public.inventory_units where barcode = v_code) = 'in_stock');
  perform pg_temp.as_postgres();
  insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty, starts_at)
  values ('db-u', null, 'retail', 910000, 1, now() - interval '1 day');
  perform pg_temp.as_user(c_staff);
  v_res := pg_temp.checkout(jsonb_build_array(jsonb_build_object('code', v_code)), '[{"price_cents":910000,"tier_code":"retail"}]', gen_random_uuid());
  perform pg_temp.check_true('K6e a unit at its confirmed price', (v_res ->> 'total_cents')::bigint = 910000 and (select status from public.inventory_units where barcode = v_code) = 'sold');
  raise notice 'K6 ok - units, variants and removed prices are covered';

  -- K7 replay: the saved bill, whatever happened to the price since --------------------------
  v_req := gen_random_uuid();
  v_res := pg_temp.checkout(c_a, '[{"price_cents":125000,"tier_code":"retail"}]', v_req);
  perform pg_temp.as_postgres();
  update public.product_prices set price_cents = 130000 where product_id = 'db-a' and tier_code = 'retail';
  perform pg_temp.as_user(c_staff);
  v_sales := (select count(*) from public.pos_sales);
  v_stock := (select stock from public.products where id = 'db-a');
  perform pg_temp.check_true('K7a replay returns the saved bill at the old price',
    pg_temp.checkout(c_a, '[{"price_cents":125000,"tier_code":"retail"}]', v_req) ->> 'bill_number' = v_res ->> 'bill_number'
    and (pg_temp.checkout(c_a, '[{"price_cents":125000,"tier_code":"retail"}]', v_req) ->> 'replayed')::boolean);
  perform pg_temp.expect_fail('K7b same id, different bill', pg_temp.checkout_sql('[{"product_id":"db-a","variant_id":null,"quantity":3}]', '[{"price_cents":130000,"tier_code":"retail"}]', v_req), 'request_id_reused:%');
  perform pg_temp.check_true('K7c nothing sold twice', (select count(*) from public.pos_sales) = v_sales and (select stock from public.products where id = 'db-a') = v_stock);
  raise notice 'K7 ok - replays return the bill; another bill under the id is refused';

  -- K8 stale discount approvals ---------------------------------------------------------------
  perform pg_temp.as_user(c_staff);
  v_req := gen_random_uuid();
  v_appr := (public.pos_request_discount_approval(v_req, c_a, null, 10000, 'old customer') ->> 'id')::uuid;
  perform pg_temp.as_user(c_admin);
  perform public.admin_decide_discount_approval(v_appr, true, '');
  perform pg_temp.as_postgres();
  update public.product_prices set price_cents = 140000 where product_id = 'db-a' and tier_code = 'retail';
  perform pg_temp.as_user(c_staff);
  v_sales := (select count(*) from public.pos_sales);
  perform pg_temp.expect_fail('K8a checkout with the new price refuses the old approval',
    format('select pg_temp.checkout(%L::jsonb, %L::jsonb, %L::uuid, null, 10000, %L::uuid)', c_a, '[{"price_cents":140000,"tier_code":"retail"}]', v_req, v_appr),
    'discount_approval_stale:%');
  perform pg_temp.expect_fail('K8b so does the older function, called directly',
    format('select public.pos_create_sale(%L::jsonb, %L, null, 10000, null, null, null, null, %L::uuid, %L::uuid)', c_a, 'cash', v_appr, v_req),
    'discount_approval_stale:%');
  perform pg_temp.check_true('K8c the approval stays unused and nothing was sold',
    (select status from public.pos_discount_approvals where id = v_appr) = 'approved'
    and (select count(*) from public.pos_sales) = v_sales);

  -- A new approval on the current prices works.
  v_appr := (public.pos_request_discount_approval(v_req, c_a, null, 10000, 'old customer') ->> 'id')::uuid;
  perform pg_temp.as_user(c_admin);
  perform public.admin_decide_discount_approval(v_appr, true, '');
  perform pg_temp.as_user(c_staff);
  v_res := pg_temp.checkout(c_a, '[{"price_cents":140000,"tier_code":"retail"}]', v_req, null, 10000, v_appr);
  perform pg_temp.check_true('K8d re-approved sale', (v_res ->> 'total_cents')::bigint = 270000 and (select status from public.pos_discount_approvals where id = v_appr) = 'used');

  -- Another bill under the same request cannot use an approval.
  v_req := gen_random_uuid();
  v_appr := (public.pos_request_discount_approval(v_req, c_a, null, 10000, 'old customer') ->> 'id')::uuid;
  perform pg_temp.as_user(c_admin);
  perform public.admin_decide_discount_approval(v_appr, true, '');
  perform pg_temp.as_user(c_staff);
  perform pg_temp.expect_fail('K8e a changed bill',
    format('select pg_temp.checkout(%L::jsonb, %L::jsonb, %L::uuid, null, 10000, %L::uuid)', '[{"product_id":"db-a","variant_id":null,"quantity":1}]', '[{"price_cents":140000,"tier_code":"retail"}]', v_req, v_appr),
    'discount_approval_required:%');
  raise notice 'K8 ok - an approval does not survive a price or bill change';

  -- K9 costs ---------------------------------------------------------------------------------
  perform pg_temp.check_true('K9 no cost in a result or a change',
    v_res::text !~* 'cost' and public.pos_check_prices(c_a, '[{"price_cents":1,"tier_code":"retail"}]', null)::text !~* 'cost');
  perform pg_temp.expect_fail('K9b staff read of cost', 'select unit_cost_cents from public.inventory_units limit 1', 'permission denied%');
  raise notice 'K9 ok - no purchase cost involved';

  raise notice 'ALL POS CHECKOUT CHECKS PASSED';
end
$$;

rollback;
