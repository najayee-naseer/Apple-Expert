-- ============================================================================
-- Apple Expert - product condition, warranty and place_order() verification
-- ----------------------------------------------------------------------------
-- Run AFTER migration 20261002120000 and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_warranty_orders.sql
--
-- Same conventions as verify.sql: every check RAISES on failure, fixtures run
-- inside one transaction that is rolled back, and role impersonation sets the
-- JWT claims PostgREST would set. A clean run ends with "ALL WARRANTY/ORDER
-- CHECKS PASSED".
-- ============================================================================

\set ON_ERROR_STOP on

begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin)
values
  ('a1111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'w-retail@test.local',  '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false),
  ('a2222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'w-vip@test.local',     '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false),
  ('a3333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'w-expired@test.local', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false),
  ('a4444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'w-admin@test.local',   '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false)
on conflict (id) do nothing;

update public.profiles set customer_type = 'wholesale_vip', vip_approved_at = now()
  where id = 'a2222222-2222-2222-2222-222222222222';
update public.profiles set customer_type = 'wholesale_vip', vip_approved_at = now() - interval '60 days',
                           vip_expires_at = now() - interval '1 day'
  where id = 'a3333333-3333-3333-3333-333333333333';
insert into public.user_roles (profile_id, role)
values ('a4444444-4444-4444-4444-444444444444', 'admin')
on conflict (profile_id, role) do nothing;

-- Catalog fixtures (as postgres): a display and a battery that sell optional
-- warranties, plus a VIP price on one iPhone variant. Since migration
-- 20261003120000 the warranty lives on the product's plan (variant_id NULL).
update public.product_warranty_plans set warranty_type = 'optional_paid'
 where product_id in ('part-iphone-15-pro-display', 'part-iphone-15-pro-battery') and variant_id is null;
-- Earlier fixtures may have left options on these plans; start clean.
delete from public.product_warranty_options
 where product_id in ('part-iphone-15-pro-display', 'part-iphone-15-pro-battery');

insert into public.product_warranty_options
  (id, product_id, plan_id, duration_months, additional_price_cents, is_enabled, is_default, display_order)
select v.id::uuid, v.product_id, pl.id, v.months, v.cents, v.enabled, v.is_default, v.ord
from (values
  ('b0000000-0000-0000-0000-000000000001', 'part-iphone-15-pro-display', 1, 0::bigint, true,  true,  0),
  ('b0000000-0000-0000-0000-000000000003', 'part-iphone-15-pro-display', 3, 150000,    true,  false, 1),
  ('b0000000-0000-0000-0000-000000000006', 'part-iphone-15-pro-display', 6, 300000,    true,  false, 2),
  ('b0000000-0000-0000-0000-000000000012', 'part-iphone-15-pro-display', 12, 500000,   false, false, 3),
  ('c0000000-0000-0000-0000-000000000003', 'part-iphone-15-pro-battery', 3, 75000,     true,  true,  0)
) as v(id, product_id, months, cents, enabled, is_default, ord)
join public.product_warranty_plans pl on pl.product_id = v.product_id and pl.variant_id is null;

insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', v.id, 'wholesale_vip', 30000000, 1
from public.product_variants v where v.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v1';

do $$
declare
  v_err     text;
  v_count   integer;
  v_result  jsonb;
  v_item    public.order_items;
  v_order   public.orders;
  v_display bigint;
begin
  select price_cents into v_display from public.product_prices
   where product_id = 'part-iphone-15-pro-display' and variant_id is null
     and tier_code = 'retail' and ends_at is null;

  -- W1 - customers cannot write warranty definitions or grades ---------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_err := null;
  begin
    insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents)
    select 'part-iphone-15-pro-display', id, 24, 0 from public.product_warranty_plans
     where product_id = 'part-iphone-15-pro-display' and variant_id is null;
  exception when others then v_err := sqlerrm; end;
  if v_err is null then raise exception 'W1 FAILED - retail customer inserted a warranty option'; end if;

  update public.product_warranty_options set additional_price_cents = 0
   where id = 'b0000000-0000-0000-0000-000000000006';
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'W1 FAILED - retail customer changed a warranty price'; end if;

  update public.products set warranty_type = 'none' where id = 'part-iphone-15-pro-display';
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'W1 FAILED - retail customer changed a warranty type'; end if;
  update public.product_warranty_plans set warranty_type = 'none' where product_id = 'part-iphone-15-pro-display';
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'W1 FAILED - retail customer changed a warranty plan'; end if;

  v_err := null;
  begin
    insert into public.condition_grades (code, label) values ('Z', 'Customer grade');
  exception when others then v_err := sqlerrm; end;
  if v_err is null then raise exception 'W1 FAILED - retail customer created a condition grade'; end if;
  perform set_config('role', 'postgres', true);
  raise notice 'W1 ok - customers cannot write warranty options, warranty types or grades';

  -- W2 - customers see enabled options only ----------------------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  select count(*) into v_count from public.product_warranty_options where product_id = 'part-iphone-15-pro-display';
  perform set_config('role', 'postgres', true);
  if v_count <> 3 then raise exception 'W2 FAILED - customer sees % display options, expected 3 enabled', v_count; end if;
  raise notice 'W2 ok - the disabled 12-month option is invisible to customers';

  -- W3 - anon cannot place orders; nobody can call the price helper ----------
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', null, true);
  v_err := null;
  begin
    perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-battery","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  perform set_config('role', 'postgres', true);
  if v_err is null then raise exception 'W3 FAILED - anonymous caller placed an order'; end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_err := null;
  begin
    perform private.live_price('iphone-17-pro-max', null, 'wholesale_vip');
  exception when others then v_err := sqlerrm; end;
  perform set_config('role', 'postgres', true);
  if v_err is null then raise exception 'W3 FAILED - a customer called private.live_price (VIP price leak)'; end if;
  raise notice 'W3 ok - anon refused by place_order; private.live_price not callable by customers';

  -- W4 - retail: display + 6-month warranty, client-supplied amounts ignored ---
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_result := pg_temp.place_order(
    '[{"product_id":"part-iphone-15-pro-display","warranty_option_id":"b0000000-0000-0000-0000-000000000006",
       "quantity":2,"unit_price_cents":1,"warranty_price_cents":0,"total_cents":1}]'::jsonb);
  perform set_config('role', 'postgres', true);

  select * into v_order from public.orders where id = (v_result ->> 'id')::uuid;
  select * into v_item from public.order_items where order_id = v_order.id;
  if v_item.base_unit_price_cents <> v_display
     or v_item.warranty_price_cents_snapshot <> 300000
     or v_item.unit_price_cents <> v_display + 300000
     or v_item.line_total_cents <> (v_display + 300000) * 2
     or v_order.total_cents <> (v_display + 300000) * 2 then
    raise exception 'W4 FAILED - wrong amounts: base % warranty % unit % line % total %',
      v_item.base_unit_price_cents, v_item.warranty_price_cents_snapshot, v_item.unit_price_cents,
      v_item.line_total_cents, v_order.total_cents;
  end if;
  if v_item.warranty_months_snapshot <> 6 or v_item.warranty_label_snapshot <> '6 Months Part Warranty'
     or v_item.condition_snapshot <> 'brand_new' or v_order.customer_type_at_purchase <> 'retail'
     or v_item.tier_code_snapshot <> 'retail' or v_order.status <> 'pending' then
    raise exception 'W4 FAILED - wrong snapshot: % / % / % / %', v_item.warranty_months_snapshot,
      v_item.warranty_label_snapshot, v_item.condition_snapshot, v_order.customer_type_at_purchase;
  end if;
  raise notice 'W4 ok - retail display x2 + 6-month warranty = % (client amounts ignored), order %',
    v_order.total_cents, v_order.order_number;

  -- W5 - historical orders never change -------------------------------------
  update public.product_warranty_options set additional_price_cents = 999999
   where id = 'b0000000-0000-0000-0000-000000000006';
  select * into v_item from public.order_items where order_id = v_order.id;
  if v_item.warranty_price_cents_snapshot <> 300000 or v_item.unit_price_cents <> v_display + 300000 then
    raise exception 'W5 FAILED - changing the warranty price rewrote an existing order';
  end if;
  update public.product_warranty_options set additional_price_cents = 300000
   where id = 'b0000000-0000-0000-0000-000000000006';
  raise notice 'W5 ok - warranty price changed 3,000 -> 9,999.99; existing order still 3,000';

  -- W6 - customers cannot alter or forge orders ------------------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_err := null;
  begin
    update public.order_items set warranty_price_cents_snapshot = 0 where order_id = v_order.id;
  exception when others then v_err := sqlerrm; end;
  if v_err is null then raise exception 'W6 FAILED - customer updated an order line'; end if;
  v_err := null;
  begin
    insert into public.orders (order_number, profile_id, customer_type_at_purchase, total_cents)
    values ('FORGED', 'a1111111-1111-1111-1111-111111111111', 'retail', 1);
  exception when others then v_err := sqlerrm; end;
  if v_err is null then raise exception 'W6 FAILED - customer inserted an order directly'; end if;
  select count(*) into v_count from public.order_items where order_id = v_order.id;
  perform set_config('role', 'postgres', true);
  if v_count <> 1 then raise exception 'W6 FAILED - customer cannot read their own order line'; end if;
  raise notice 'W6 ok - order lines immutable, direct order insert refused, own order readable';

  -- W7 - invalid selections are refused --------------------------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  -- disabled option
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-display","warranty_option_id":"b0000000-0000-0000-0000-000000000012","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'warranty_option_invalid%' then raise exception 'W7 FAILED - disabled option: %', v_err; end if;
  -- another product's option
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-display","warranty_option_id":"c0000000-0000-0000-0000-000000000003","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'warranty_option_invalid%' then raise exception 'W7 FAILED - foreign option: %', v_err; end if;
  -- warranty option on a product without selectable warranty
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","warranty_option_id":"b0000000-0000-0000-0000-000000000003","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'warranty_not_applicable%' then raise exception 'W7 FAILED - not applicable: %', v_err; end if;
  -- variant required
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"iphone-17-pro-max","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'variant_required%' then raise exception 'W7 FAILED - variant required: %', v_err; end if;
  -- missing / zero / fractional quantity
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-battery"}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'invalid_quantity%' then raise exception 'W7 FAILED - missing qty: %', v_err; end if;
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-battery","quantity":0}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'invalid_quantity%' then raise exception 'W7 FAILED - zero qty: %', v_err; end if;
  -- more than the stock on record (display stock is 12)
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-display","quantity":13}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'insufficient_stock%' then raise exception 'W7 FAILED - stock: %', v_err; end if;
  -- unpublished product
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"no-such-product","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'product_unavailable%' then raise exception 'W7 FAILED - unknown product: %', v_err; end if;
  perform set_config('role', 'postgres', true);
  raise notice 'W7 ok - disabled/foreign/inapplicable warranty, missing variant, bad qty, over-stock, unknown product all refused';

  -- W8 - no option given -> the product's default option ---------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_result := pg_temp.place_order('[{"product_id":"part-iphone-15-pro-battery","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  if v_item.warranty_option_id <> 'c0000000-0000-0000-0000-000000000003'
     or v_item.warranty_label_snapshot <> '3 Months Battery Warranty'
     or v_item.warranty_price_cents_snapshot <> 75000 then
    raise exception 'W8 FAILED - default warranty not applied: % / %', v_item.warranty_label_snapshot, v_item.warranty_price_cents_snapshot;
  end if;
  raise notice 'W8 ok - battery with no explicit choice got its default "3 Months Battery Warranty" (+750)';

  -- W9 - VIP pays the VIP price; expired VIP and retail pay retail ------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
  v_result := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  select * into v_order from public.orders where id = (v_result ->> 'id')::uuid;
  if v_item.unit_price_cents <> 30000000 or v_item.tier_code_snapshot <> 'wholesale_vip'
     or v_order.customer_type_at_purchase <> 'wholesale_vip'
     or v_item.warranty_label_snapshot is distinct from 'Included warranty'
        and v_item.warranty_label_snapshot not like '% Warranty (included)' then
    raise exception 'W9 FAILED - VIP line: % % % %', v_item.unit_price_cents, v_item.tier_code_snapshot,
      v_order.customer_type_at_purchase, v_item.warranty_label_snapshot;
  end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a3333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
  v_result := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  if v_item.unit_price_cents <> 35900000 or v_item.tier_code_snapshot <> 'retail' then
    raise exception 'W9 FAILED - expired VIP charged % at %', v_item.unit_price_cents, v_item.tier_code_snapshot;
  end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_result := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  if v_item.unit_price_cents <> 35900000 then
    raise exception 'W9 FAILED - retail charged %', v_item.unit_price_cents;
  end if;
  raise notice 'W9 ok - VIP 300,000 (wholesale_vip); expired VIP and retail 359,000 (retail)';

  -- W10 - VIP with no VIP row falls back to retail + warranty -----------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
  v_result := pg_temp.place_order('[{"product_id":"part-iphone-15-pro-display","warranty_option_id":"b0000000-0000-0000-0000-000000000003","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  if v_item.unit_price_cents <> v_display + 150000 or v_item.tier_code_snapshot <> 'retail' then
    raise exception 'W10 FAILED - VIP fallback line: % %', v_item.unit_price_cents, v_item.tier_code_snapshot;
  end if;
  raise notice 'W10 ok - VIP without a VIP display price pays retail + the same warranty add-on';

  -- W11 - admins manage warranty and grades through RLS -----------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a4444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
  insert into public.condition_grades (code, label, description) values ('TEST', 'Test grade', 'fixture');
  insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents, display_order)
  select 'part-iphone-15-pro-battery', id, 6, 150000, 1 from public.product_warranty_plans
   where product_id = 'part-iphone-15-pro-battery' and variant_id is null;
  update public.product_warranty_plans set warranty_title = 'Battery warranty', warranty_covered = array['Battery defects']
   where product_id = 'part-iphone-15-pro-battery' and variant_id is null;
  get diagnostics v_count = row_count;
  v_err := null;
  begin
    update public.product_warranty_options set is_default = true
     where id = 'b0000000-0000-0000-0000-000000000003';
  exception when others then v_err := sqlerrm; end;
  perform set_config('role', 'postgres', true);
  if v_count <> 1 then raise exception 'W11 FAILED - admin could not edit warranty terms'; end if;
  if v_err is null then raise exception 'W11 FAILED - a second default warranty option was accepted'; end if;
  raise notice 'W11 ok - admin writes grades/options/terms; a second default per product is refused';

  -- W12 - store switches close ordering at the database ----------------------
  update public.store_settings set maintenance_mode = true where id;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-battery","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  perform set_config('role', 'postgres', true);
  update public.store_settings set maintenance_mode = false where id;
  if v_err not like 'store_unavailable%' then raise exception 'W12 FAILED - order placed during maintenance: %', v_err; end if;

  update public.store_settings set wholesale_enabled = false where id;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
  v_err := null;
  begin perform pg_temp.place_order('[{"product_id":"part-iphone-15-pro-battery","quantity":1}]'::jsonb);
  exception when others then v_err := sqlerrm; end;
  perform set_config('role', 'postgres', true);
  update public.store_settings set wholesale_enabled = true where id;
  if v_err not like 'store_unavailable%' then raise exception 'W12 FAILED - VIP ordered with wholesale closed: %', v_err; end if;
  raise notice 'W12 ok - maintenance mode and a closed wholesale store refuse orders';

  -- W13 - existing products migrated sensibly --------------------------------
  select count(*) into v_count from public.products
   where (warranty_status = 'active') <> (warranty_type = 'included')
     and id not in ('part-iphone-15-pro-display', 'part-iphone-15-pro-battery');
  if v_count <> 0 then raise exception 'W13 FAILED - % products with a mismatched warranty_type backfill', v_count; end if;
  select count(*) into v_count from public.products p
   where not exists (select 1 from public.product_warranty_plans pl where pl.product_id = p.id and pl.variant_id is null);
  if v_count <> 0 then raise exception 'W13 FAILED - % products without a product-level warranty plan', v_count; end if;
  raise notice 'W13 ok - warranty_type backfilled from warranty_status; every product has a warranty plan';

  raise notice 'ALL WARRANTY/ORDER CHECKS PASSED';
end;
$$;

rollback;
