-- ============================================================================
-- Apple Expert - per-variant condition, warranty plans and variant images
-- (migration 20261003120000) verification
-- ----------------------------------------------------------------------------
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_variant_conditions.sql
--
-- Same conventions as verify.sql: RAISES on failure, everything inside one
-- rolled-back transaction, role impersonation through the JWT claims. A clean
-- run ends with "ALL VARIANT CONDITION CHECKS PASSED".
--
-- Fixture product: iphone-17-pro-max (variants v1..v4). Its products.condition
-- is deliberately set to the LEGACY product-level 'pre_owned' here, so every
-- check that a Brand New variant snapshots 'brand_new' also proves the order
-- never reads products.condition.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin)
values
  ('c1111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'v-retail@test.local', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false),
  ('c2222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'v-vip@test.local',    '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false),
  ('c4444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'v-admin@test.local',  '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false)
on conflict (id) do nothing;
update public.profiles set customer_type = 'wholesale_vip', vip_approved_at = now()
 where id = 'c2222222-2222-2222-2222-222222222222';
insert into public.user_roles (profile_id, role) values ('c4444444-4444-4444-4444-444444444444', 'admin')
on conflict (profile_id, role) do nothing;

-- Legacy product-level value (as on production): must be IGNORED for variants.
update public.products set condition = 'pre_owned', battery_health = 89 where id = 'iphone-17-pro-max';

insert into public.condition_grades (id, code, label, description) values
  ('d1000000-0000-0000-0000-00000000000a', 'VA', 'Grade A', 'fixture'),
  ('d1000000-0000-0000-0000-00000000000b', 'VB', 'Grade B', 'fixture');

do $$
declare
  v_err   text;
  v_count integer;
  v_res   jsonb;
  v_item  public.order_items;
  v1 uuid; v2 uuid; v3 uuid; v4 uuid; other_variant uuid; v_del uuid; plan_del uuid;
  plan_product uuid; plan_v2 uuid; plan_v3 uuid;
  opt_p12 uuid; opt_v2_3 uuid; opt_v2_6 uuid;
  price_v2 bigint; price_v1 bigint; price_v4 bigint;
begin
  select id into v1 from public.product_variants where product_id = 'iphone-17-pro-max' and legacy_key = 'v1';
  select id into v2 from public.product_variants where product_id = 'iphone-17-pro-max' and legacy_key = 'v2';
  select id into v3 from public.product_variants where product_id = 'iphone-17-pro-max' and legacy_key = 'v3';
  select id into v4 from public.product_variants where product_id = 'iphone-17-pro-max' and legacy_key = 'v4';
  select id into other_variant from public.product_variants where product_id <> 'iphone-17-pro-max' limit 1;
  select price_cents into price_v1 from public.product_prices where variant_id = v1 and tier_code = 'retail' and ends_at is null;
  select price_cents into price_v2 from public.product_prices where variant_id = v2 and tier_code = 'retail' and ends_at is null;
  select price_cents into price_v4 from public.product_prices where variant_id = v4 and tier_code = 'retail' and ends_at is null;

  -- V1 - a variant must belong to the referenced product ----------------------
  v_err := null;
  begin insert into public.product_conditions (product_id, variant_id, condition) values ('iphone-17-pro-max', other_variant, 'pre_owned');
  exception when foreign_key_violation then v_err := 'fk'; end;
  if v_err is null then raise exception 'V1 FAILED - condition row paired a product with another product''s variant'; end if;
  v_err := null;
  begin insert into public.product_warranty_plans (product_id, variant_id) values ('iphone-17-pro-max', other_variant);
  exception when foreign_key_violation then v_err := 'fk'; end;
  if v_err is null then raise exception 'V1 FAILED - warranty plan paired a product with another product''s variant'; end if;
  v_err := null;
  begin insert into public.product_images (product_id, variant_id, path) values ('iphone-17-pro-max', other_variant, '/x.jpg');
  exception when foreign_key_violation then v_err := 'fk'; end;
  if v_err is null then raise exception 'V1 FAILED - image paired a product with another product''s variant'; end if;
  raise notice 'V1 ok - conditions, plans and images cannot reference another product''s variant';

  -- V2 - one row per product/variant -------------------------------------------
  insert into public.product_conditions (product_id, variant_id, condition, condition_grade_id, battery_health, cycle_count)
  values ('iphone-17-pro-max', v2, 'pre_owned', 'd1000000-0000-0000-0000-00000000000a', 92, 180);
  v_err := null;
  begin insert into public.product_conditions (product_id, variant_id, condition) values ('iphone-17-pro-max', v2, 'brand_new');
  exception when unique_violation then v_err := 'dup'; end;
  if v_err is null then raise exception 'V2 FAILED - two condition rows for one variant'; end if;
  v_err := null;
  begin insert into public.product_conditions (product_id, variant_id, condition) values ('iphone-13-mini', null, 'brand_new');
  exception when unique_violation then v_err := 'dup'; end;
  if v_err is null then raise exception 'V2 FAILED - two product-level condition rows for one product'; end if;
  raise notice 'V2 ok - one condition row per variant and per variant-less product';

  -- V3 - variants are independent ----------------------------------------------
  select count(*) into v_count from public.product_conditions where product_id = 'iphone-17-pro-max' and variant_id in (v1, v3, v4);
  if v_count <> 0 then raise exception 'V3 FAILED - configuring v2 created rows for other variants'; end if;
  update public.product_conditions set condition_grade_id = 'd1000000-0000-0000-0000-00000000000b' where variant_id = v2;
  select count(*) into v_count from public.product_conditions where product_id = 'iphone-17-pro-max';
  if v_count <> 1 then raise exception 'V3 FAILED - editing v2 touched other variants'; end if;
  update public.product_conditions set condition_grade_id = 'd1000000-0000-0000-0000-00000000000a' where variant_id = v2;
  select count(*) into v_count from public.products where id = 'iphone-17-pro-max' and condition = 'pre_owned' and battery_health = 89;
  if v_count <> 1 then raise exception 'V3 FAILED - a variant row changed the product-level legacy columns'; end if;
  raise notice 'V3 ok - 128GB/512GB stay without rows (Brand New) while 256GB is Pre-Owned; legacy columns untouched';

  -- V4 - warranty plans: product default, variant overrides ----------------------
  select id into plan_product from public.product_warranty_plans where product_id = 'iphone-17-pro-max' and variant_id is null;
  update public.product_warranty_plans set warranty_type = 'optional_paid' where id = plan_product;
  insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents, is_default)
  values ('iphone-17-pro-max', plan_product, 12, 0, true) returning id into opt_p12;
  insert into public.product_warranty_plans (product_id, variant_id, warranty_type, warranty_title)
  values ('iphone-17-pro-max', v2, 'optional_paid', 'Pre-owned cover') returning id into plan_v2;
  insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents, is_default)
  values ('iphone-17-pro-max', plan_v2, 3, 0, true) returning id into opt_v2_3;
  insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents)
  values ('iphone-17-pro-max', plan_v2, 6, 500000) returning id into opt_v2_6;
  insert into public.product_warranty_plans (product_id, variant_id, warranty_type)
  values ('iphone-17-pro-max', v3, 'none') returning id into plan_v3;
  v_err := null;
  begin insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents)
        values ('iphone-17-pro', plan_v2, 9, 0);
  exception when foreign_key_violation then v_err := 'fk'; end;
  if v_err is null then raise exception 'V4 FAILED - an option was attached to another product''s plan'; end if;
  v_err := null;
  begin insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents, is_default)
        values ('iphone-17-pro-max', plan_v2, 9, 0, true);
  exception when unique_violation then v_err := 'dup'; end;
  if v_err is null then raise exception 'V4 FAILED - a second default option on one plan'; end if;
  -- the same duration may exist on different plans (12 on product plan, 12 allowed on v2's)
  insert into public.product_warranty_options (product_id, plan_id, duration_months, additional_price_cents, is_enabled)
  values ('iphone-17-pro-max', plan_v2, 12, 900000, false);
  raise notice 'V4 ok - product plan + variant overrides; one default and unique durations per plan; options stay on their product';

  -- V5 - orders snapshot the SELECTED variant's condition and warranty -------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  -- 256GB pre-owned + its own 6-month override option, with tampered amounts
  v_res := pg_temp.place_order(format('[{"product_id":"iphone-17-pro-max","variant_key":"v2","warranty_option_id":"%s","quantity":1,"unit_price_cents":1,"warranty_price_cents":0}]', opt_v2_6)::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_res ->> 'id')::uuid;
  if v_item.condition_snapshot <> 'pre_owned' or v_item.condition_grade_snapshot <> 'Grade A'
     or v_item.base_unit_price_cents <> price_v2 or v_item.warranty_price_cents_snapshot <> 500000
     or v_item.unit_price_cents <> price_v2 + 500000 or v_item.warranty_label_snapshot <> '6 Months Warranty' then
    raise exception 'V5 FAILED - v2 line: % % % % %', v_item.condition_snapshot, v_item.condition_grade_snapshot,
      v_item.base_unit_price_cents, v_item.warranty_price_cents_snapshot, v_item.warranty_label_snapshot;
  end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_res := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_res ->> 'id')::uuid;
  if v_item.condition_snapshot <> 'brand_new' or v_item.condition_grade_snapshot is not null then
    raise exception 'V5 FAILED - v1 took a condition from the product: %', v_item.condition_snapshot;
  end if;
  if v_item.warranty_option_id <> opt_p12 or v_item.warranty_label_snapshot <> '12 Months Warranty' then
    raise exception 'V5 FAILED - v1 did not use the product default plan: %', v_item.warranty_label_snapshot;
  end if;
  raise notice 'V5 ok - 256GB snapshots pre_owned / Grade A / 6-month override (client amounts ignored); 128GB snapshots brand_new + product default warranty, not the legacy product value';

  -- V6 - fallback, no warranty, invalid options ----------------------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_res := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v4","quantity":1}]'::jsonb);
  select * into v_item from public.order_items where order_id = (v_res ->> 'id')::uuid;
  if v_item.warranty_option_id <> opt_p12 or v_item.condition_snapshot <> 'brand_new' or v_item.base_unit_price_cents <> price_v4 then
    raise exception 'V6 FAILED - v4 (no override) did not fall back to the product plan';
  end if;
  v_res := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v3","quantity":1}]'::jsonb);
  select * into v_item from public.order_items where order_id = (v_res ->> 'id')::uuid;
  if v_item.warranty_label_snapshot is not null or v_item.warranty_price_cents_snapshot <> 0 then
    raise exception 'V6 FAILED - v3 (override: none) recorded a warranty';
  end if;
  v_err := null;
  begin perform pg_temp.place_order(format('[{"product_id":"iphone-17-pro-max","variant_key":"v3","warranty_option_id":"%s","quantity":1}]', opt_p12)::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'warranty_not_applicable%' then raise exception 'V6 FAILED - v3 accepted a warranty: %', v_err; end if;
  v_err := null;
  begin perform pg_temp.place_order(format('[{"product_id":"iphone-17-pro-max","variant_key":"v1","warranty_option_id":"%s","quantity":1}]', opt_v2_6)::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'warranty_option_invalid%' then raise exception 'V6 FAILED - v1 accepted v2''s option: %', v_err; end if;
  v_err := null;
  begin perform pg_temp.place_order(format('[{"product_id":"iphone-17-pro-max","variant_key":"v2","warranty_option_id":"%s","quantity":1}]', opt_p12)::jsonb);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'warranty_option_invalid%' then raise exception 'V6 FAILED - v2 accepted the product plan option it overrides: %', v_err; end if;
  perform set_config('role', 'postgres', true);
  raise notice 'V6 ok - 1TB falls back to the product plan; 512GB override "none" has no warranty; options from another plan are refused';

  -- V7 - variant-less products ---------------------------------------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_res := pg_temp.place_order('[{"product_id":"iphone-13-mini","quantity":1},{"product_id":"acc-magsafe-charger","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select count(*) into v_count from public.order_items
   where order_id = (v_res ->> 'id')::uuid
     and ((product_id = 'iphone-13-mini' and condition_snapshot = (select condition from public.product_conditions where product_id = 'iphone-13-mini'))
       or (product_id = 'acc-magsafe-charger' and condition_snapshot = 'brand_new'));
  if v_count <> 2 then raise exception 'V7 FAILED - variant-less products did not use their product-level rows'; end if;
  delete from public.product_conditions where product_id = 'acc-magsafe-charger';
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  v_res := pg_temp.place_order('[{"product_id":"acc-magsafe-charger","quantity":1}]'::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_res ->> 'id')::uuid;
  if v_item.condition_snapshot <> 'brand_new' then raise exception 'V7 FAILED - no row did not mean Brand New'; end if;
  raise notice 'V7 ok - variant-less products use their (product, NULL) row; no row = Brand New';

  -- V8 - VIP pays the VIP variant price + the same warranty add-on -------------
  insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
  values ('iphone-17-pro-max', v2, 'wholesale_vip', 30000000, 1);
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
  v_res := pg_temp.place_order(format('[{"product_id":"iphone-17-pro-max","variant_key":"v2","warranty_option_id":"%s","quantity":1}]', opt_v2_6)::jsonb);
  perform set_config('role', 'postgres', true);
  select * into v_item from public.order_items where order_id = (v_res ->> 'id')::uuid;
  if v_item.unit_price_cents <> 30000000 + 500000 or v_item.tier_code_snapshot <> 'wholesale_vip' or v_item.condition_snapshot <> 'pre_owned' then
    raise exception 'V8 FAILED - VIP v2 line: % %', v_item.unit_price_cents, v_item.tier_code_snapshot;
  end if;
  raise notice 'V8 ok - VIP 256GB Pre-Owned: Rs. 300,000 + Rs. 5,000 warranty';

  -- V9 - RLS: customers read, never write; anonymous never writes ----------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  select count(*) into v_count from public.product_conditions where product_id = 'iphone-17-pro-max';
  if v_count <> 1 then raise exception 'V9 FAILED - customer cannot read variant conditions'; end if;
  v_err := null;
  begin insert into public.product_conditions (product_id, variant_id, condition) values ('iphone-17-pro-max', v1, 'pre_owned');
  exception when others then v_err := sqlerrm; end;
  if v_err is null then raise exception 'V9 FAILED - customer wrote a condition'; end if;
  update public.product_conditions set condition = 'brand_new' where variant_id = v2;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'V9 FAILED - customer changed a condition'; end if;
  update public.product_warranty_plans set warranty_type = 'none' where id = plan_v2;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'V9 FAILED - customer changed a warranty plan'; end if;
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', null, true);
  v_err := null;
  begin insert into public.product_warranty_plans (product_id, variant_id) values ('iphone-17-pro-max', v4);
  exception when others then v_err := sqlerrm; end;
  if v_err is null then raise exception 'V9 FAILED - anonymous caller created a plan'; end if;
  perform set_config('role', 'postgres', true);
  update public.products set is_active = false where id = 'iphone-13-mini';
  perform set_config('role', 'anon', true);
  select count(*) into v_count from public.product_conditions where product_id = 'iphone-13-mini';
  perform set_config('role', 'postgres', true);
  update public.products set is_active = true where id = 'iphone-13-mini';
  if v_count <> 0 then raise exception 'V9 FAILED - an unpublished product''s condition is public'; end if;
  raise notice 'V9 ok - customers read live rows only; customers and anonymous callers cannot write conditions or plans';

  -- V10 - admin writes; product-level rows mirror into the legacy columns --------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c4444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
  insert into public.product_conditions (product_id, variant_id, condition) values ('acc-magsafe-charger', null, 'pre_owned');
  update public.product_conditions set battery_health = 77 where variant_id = v2;
  insert into public.product_images (product_id, variant_id, path) values ('iphone-17-pro-max', v2, 'iphone-17-pro-max/unit.jpg');
  perform set_config('role', 'postgres', true);
  select count(*) into v_count from public.products where id = 'acc-magsafe-charger' and condition = 'pre_owned';
  if v_count <> 1 then raise exception 'V10 FAILED - product-level row was not mirrored to products.condition'; end if;
  select count(*) into v_count from public.products where id = 'iphone-17-pro-max' and battery_health = 89;
  if v_count <> 1 then raise exception 'V10 FAILED - a variant row was mirrored to the product'; end if;
  raise notice 'V10 ok - admin manages conditions/images; product-level rows mirror to legacy columns, variant rows never do';

  -- V11 - a variant that has been ordered keeps its history and cannot be deleted
  -- (20261101100000: stock_reservations restricts it); one with no history can,
  -- and only its own condition, plan and images go with it.
  begin
    delete from public.product_variants where id = v2;
    raise exception 'V11 FAILED - a variant with order history was deleted';
  exception when foreign_key_violation then
    null;
  end;
  insert into public.product_variants (product_id, legacy_key, name)
  values ('iphone-17-pro-max', 'v-del', 'No history') returning id into v_del;
  insert into public.product_conditions (product_id, variant_id, condition) values ('iphone-17-pro-max', v_del, 'pre_owned');
  insert into public.product_warranty_plans (product_id, variant_id, warranty_type, warranty_title)
  values ('iphone-17-pro-max', v_del, 'optional_paid', 'Temp cover') returning id into plan_del;
  insert into public.product_images (product_id, variant_id, path) values ('iphone-17-pro-max', v_del, 'iphone-17-pro-max/temp.jpg');
  delete from public.product_variants where id = v_del;
  select count(*) into v_count from public.product_conditions where variant_id = v_del;
  if v_count <> 0 then raise exception 'V11 FAILED - variant condition survived its variant'; end if;
  select count(*) into v_count from public.product_warranty_plans where id = plan_del;
  if v_count <> 0 then raise exception 'V11 FAILED - variant plan survived its variant'; end if;
  select count(*) into v_count from public.product_images where variant_id = v_del;
  if v_count <> 0 then raise exception 'V11 FAILED - variant image survived its variant'; end if;
  select count(*) into v_count from public.product_warranty_plans where id = plan_product;
  if v_count <> 1 then raise exception 'V11 FAILED - the product plan was removed with a variant'; end if;
  raise notice 'V11 ok - ordered variants are kept; otherwise its condition, plan and images go with it; the product plan stays';

  raise notice 'ALL VARIANT CONDITION CHECKS PASSED';
end;
$$;

rollback;
