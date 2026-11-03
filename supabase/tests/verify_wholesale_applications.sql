-- ============================================================================
-- Apple Expert - wholesale application workflow verification
-- ----------------------------------------------------------------------------
-- Run AFTER migration 20261005120000 and the seed, as postgres:
--
--   docker exec -i supabase_db_apple-expert psql -U postgres \
--     < supabase/tests/verify_wholesale_applications.sql
--
-- Same conventions as verify.sql: every check RAISES on failure, fixtures run
-- inside one transaction that is rolled back, and role impersonation sets the
-- JWT claims PostgREST would set. A clean run ends with
-- "ALL WHOLESALE APPLICATION CHECKS PASSED".
--
-- "Portal access" below means what the app and the database both key on:
-- private.current_customer_type() = 'wholesale_vip' (the route guard mirrors
-- it), plus whether RLS releases wholesale_vip price rows to the caller.
-- ============================================================================

\set ON_ERROR_STOP on

begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '',
       now(), now(), now(), '{}'::jsonb, '{}'::jsonb, false
from (values
  ('e1111111-1111-1111-1111-111111111111', 'wa-new@test.local'),
  ('e2222222-2222-2222-2222-222222222222', 'wa-draft@test.local'),
  ('e3333333-3333-3333-3333-333333333333', 'wa-submitted@test.local'),
  ('e4444444-4444-4444-4444-444444444444', 'wa-assist@test.local'),
  ('e5555555-5555-5555-5555-555555555555', 'wa-review@test.local'),
  ('e6666666-6666-6666-6666-666666666666', 'wa-rejected@test.local'),
  ('e7777777-7777-7777-7777-777777777777', 'wa-existing-vip@test.local'),
  ('e8888888-8888-8888-8888-888888888888', 'wa-admin@test.local'),
  ('e9999999-9999-9999-9999-999999999999', 'wa-staff@test.local')
) as u(id, email)
on conflict (id) do nothing;

-- A customer who was made Wholesale VIP before this workflow existed.
update public.profiles set customer_type = 'wholesale_vip', vip_approved_at = now() - interval '30 days'
 where id = 'e7777777-7777-7777-7777-777777777777';

insert into public.user_roles (profile_id, role) values
  ('e8888888-8888-8888-8888-888888888888', 'admin'),
  ('e9999999-9999-9999-9999-999999999999', 'staff')
on conflict (profile_id, role) do nothing;

-- A VIP price on one variant so the tier split is observable (kept if the seed already has one).
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', v.id, 'wholesale_vip', 30000000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices p
     where p.product_id = 'iphone-17-pro-max' and p.variant_id = v.id
       and p.tier_code = 'wholesale_vip' and p.ends_at is null);

-- ----------------------------------------------------------------------------
-- Helpers (session-local, dropped with the transaction's session)
-- ----------------------------------------------------------------------------
create function pg_temp.as_user(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
end $$;

create function pg_temp.as_postgres() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', null, true);
end $$;

-- What the caller would get: their resolved tier, how many VIP price rows RLS
-- releases to them, and the effective price of the fixture variant.
create function pg_temp.access_of(p_uid uuid, out tier text, out vip_rows integer, out effective bigint)
language plpgsql as $$
begin
  perform pg_temp.as_user(p_uid);
  tier := private.current_customer_type();
  select count(*) into vip_rows from public.product_prices where tier_code = 'wholesale_vip';
  select e.price_cents into effective
    from public.my_effective_prices e
    join public.product_variants v on v.id = e.variant_id
   where e.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v1';
  perform pg_temp.as_postgres();
end $$;

create function pg_temp.assert_no_portal(p_uid uuid, p_label text) returns void language plpgsql as $$
declare a record;
begin
  select * into a from pg_temp.access_of(p_uid);
  if a.tier <> 'retail' or a.vip_rows <> 0 then
    raise exception '% FAILED - tier %, % VIP price rows visible', p_label, a.tier, a.vip_rows;
  end if;
end $$;

create function pg_temp.fields(p_name text) returns jsonb language sql as $$
  select jsonb_build_object('business_name', p_name, 'business_registration', 'PV-1001',
    'contact_phone', '0771234567', 'business_type', 'Repair shop',
    'monthly_volume', '10 – 50 units', 'message', 'Test application');
$$;

do $$
declare
  v_err      text;
  v_row      public.wholesale_access_requests;
  v_id       uuid;
  v_count    integer;
  v_retail   bigint;
  v_vip      bigint;
  v_result   jsonb;
  v_item     public.order_items;
  a          record;
begin
  select pp.price_cents into v_retail
    from public.product_prices pp join public.product_variants v on v.id = pp.variant_id
   where pp.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v1' and pp.tier_code = 'retail' and pp.ends_at is null;
  if v_retail is null then
    select price_cents into v_retail from public.product_prices
     where product_id = 'iphone-17-pro-max' and variant_id is null and tier_code = 'retail' and ends_at is null;
  end if;
  select pp.price_cents into v_vip
    from public.product_prices pp join public.product_variants v on v.id = pp.variant_id
   where pp.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v1' and pp.tier_code = 'wholesale_vip' and pp.ends_at is null;

  -- ---------------------------------------------------------------- fixtures
  -- Each customer reaches their state through the real customer RPC.
  perform pg_temp.as_user('e2222222-2222-2222-2222-222222222222');
  perform public.customer_save_wholesale_application(jsonb_build_object('business_name', 'Half Done Ltd'), 'draft');
  perform pg_temp.as_user('e3333333-3333-3333-3333-333333333333');
  perform public.customer_save_wholesale_application(pg_temp.fields('Submitted Traders'), 'submit');
  perform pg_temp.as_user('e5555555-5555-5555-5555-555555555555');
  perform public.customer_save_wholesale_application(pg_temp.fields('Review Co'), 'submit');
  perform pg_temp.as_user('e6666666-6666-6666-6666-666666666666');
  perform public.customer_save_wholesale_application(pg_temp.fields('Rejected Mobile'), 'submit');
  perform pg_temp.as_postgres();

  -- Admin moves one to under_review and rejects another.
  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  select id into v_id from public.wholesale_access_requests where profile_id = 'e5555555-5555-5555-5555-555555555555';
  v_row := public.admin_update_wholesale_request(v_id, null, 'Looking at this one.');
  if v_row.status <> 'pending' then raise exception 'FIXTURE - notes-only save must not change status'; end if;
  v_row := public.admin_update_wholesale_request(v_id, pg_temp.fields('Review Co'), null);
  if v_row.status <> 'under_review' then raise exception 'FIXTURE - admin edit did not move to under_review'; end if;
  select id into v_id from public.wholesale_access_requests where profile_id = 'e6666666-6666-6666-6666-666666666666';
  perform public.admin_review_wholesale_request(v_id, 'rejected', 'Your wholesale application needs additional information.');
  perform pg_temp.as_postgres();

  -- WA1-WA6 - nobody short of approved gets the portal or VIP prices ---------
  perform pg_temp.assert_no_portal('e1111111-1111-1111-1111-111111111111', 'WA1 (new customer)');
  perform pg_temp.assert_no_portal('e2222222-2222-2222-2222-222222222222', 'WA2 (draft)');
  perform pg_temp.assert_no_portal('e3333333-3333-3333-3333-333333333333', 'WA3 (submitted)');
  perform pg_temp.assert_no_portal('e5555555-5555-5555-5555-555555555555', 'WA5 (under review)');
  perform pg_temp.assert_no_portal('e6666666-6666-6666-6666-666666666666', 'WA6 (rejected)');
  select status into v_err from public.wholesale_access_requests where profile_id = 'e2222222-2222-2222-2222-222222222222';
  if v_err <> 'draft' then raise exception 'WA2 FAILED - draft fixture is %', v_err; end if;
  raise notice 'WA1-3,5,6 ok - new, draft, submitted, under-review and rejected customers: retail tier, 0 VIP rows';

  -- WA8 - customer requests admin assistance (nothing filled in) -------------
  perform pg_temp.as_user('e4444444-4444-4444-4444-444444444444');
  v_row := public.customer_save_wholesale_application('{}'::jsonb, 'assistance');
  perform pg_temp.as_postgres();
  if v_row.status <> 'assistance_requested' or v_row.assistance_requested_at is null
     or v_row.submitted_at is null or v_row.business_name <> '' then
    raise exception 'WA8 FAILED - assistance row: % % %', v_row.status, v_row.assistance_requested_at, v_row.business_name;
  end if;
  -- A submitted customer may also ask for help afterwards, without their fields changing.
  perform pg_temp.as_user('e3333333-3333-3333-3333-333333333333');
  v_row := public.customer_save_wholesale_application(pg_temp.fields('SHOULD BE IGNORED'), 'assistance');
  perform pg_temp.as_postgres();
  if v_row.status <> 'assistance_requested' or v_row.business_name <> 'Submitted Traders' then
    raise exception 'WA8 FAILED - pending -> assistance: % %', v_row.status, v_row.business_name;
  end if;
  raise notice 'WA8 ok - assistance requested from blank and from submitted; submitted fields untouched';

  -- WA4 - assistance requested still has no access ---------------------------
  perform pg_temp.assert_no_portal('e4444444-4444-4444-4444-444444444444', 'WA4 (assistance requested)');
  raise notice 'WA4 ok - assistance-requested customer: retail tier, 0 VIP rows';

  -- WA9 - it appears in the admin queue (staff and admin read it) ------------
  perform pg_temp.as_user('e9999999-9999-9999-9999-999999999999');
  select count(*) into v_count from public.wholesale_access_requests
   where profile_id = 'e4444444-4444-4444-4444-444444444444' and status = 'assistance_requested';
  perform pg_temp.as_postgres();
  if v_count <> 1 then raise exception 'WA9 FAILED - staff sees % assistance rows', v_count; end if;
  -- ...but another customer does not.
  perform pg_temp.as_user('e1111111-1111-1111-1111-111111111111');
  select count(*) into v_count from public.wholesale_access_requests;
  perform pg_temp.as_postgres();
  if v_count <> 0 then raise exception 'WA9 FAILED - a customer can read % other applications', v_count; end if;
  raise notice 'WA9 ok - assistance request visible to staff/admin, invisible to other customers';

  -- WA10-WA12 - admin opens, fills in and saves it ----------------------------
  select id into v_id from public.wholesale_access_requests
   where profile_id = 'e4444444-4444-4444-4444-444444444444' and status = 'assistance_requested';
  -- staff may read but not edit
  perform pg_temp.as_user('e9999999-9999-9999-9999-999999999999');
  v_err := null;
  begin perform public.admin_update_wholesale_request(v_id, pg_temp.fields('Staff Edit'), null);
  exception when others then v_err := sqlstate; end;
  perform pg_temp.as_postgres();
  if v_err is distinct from '42501' then raise exception 'WA11 FAILED - staff edit not refused (%)', v_err; end if;

  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  v_row := public.admin_update_wholesale_request(v_id, pg_temp.fields('Assisted Holdings'), 'Completed by phone.');
  perform pg_temp.as_postgres();
  if v_row.status <> 'under_review' or v_row.business_name <> 'Assisted Holdings'
     or v_row.admin_updated_by <> 'e8888888-8888-8888-8888-888888888888'
     or (v_row.customer_values ->> 'business_name') is not null then
    raise exception 'WA11/12 FAILED - saved row: % % % %', v_row.status, v_row.business_name,
      v_row.admin_updated_by, v_row.customer_values;
  end if;
  if not exists (select 1 from public.wholesale_access_request_notes where request_id = v_id and admin_notes = 'Completed by phone.') then
    raise exception 'WA12 FAILED - internal note not saved';
  end if;
  raise notice 'WA10-12 ok - admin completed and saved the application; customer snapshot kept; staff refused';

  -- Internal notes are never visible to the applicant.
  perform pg_temp.as_user('e4444444-4444-4444-4444-444444444444');
  select count(*) into v_count from public.wholesale_access_request_notes;
  perform pg_temp.as_postgres();
  if v_count <> 0 then raise exception 'WA12 FAILED - applicant can read % internal notes', v_count; end if;
  raise notice 'WA12 ok - internal notes hidden from the applicant';

  -- WA13-WA15 - approval grants the existing wholesale_vip tier ---------------
  perform pg_temp.as_user('e9999999-9999-9999-9999-999999999999');
  v_err := null;
  begin perform public.admin_review_wholesale_request(v_id, 'approved', null);
  exception when others then v_err := sqlstate; end;
  perform pg_temp.as_postgres();
  if v_err is distinct from '42501' then raise exception 'WA13 FAILED - staff approval not refused (%)', v_err; end if;

  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  v_row := public.admin_review_wholesale_request(v_id, 'approved', null);
  perform pg_temp.as_postgres();
  if v_row.status <> 'approved' or v_row.reviewed_by <> 'e8888888-8888-8888-8888-888888888888' or v_row.reviewed_at is null then
    raise exception 'WA13 FAILED - approved row: % % %', v_row.status, v_row.reviewed_by, v_row.reviewed_at;
  end if;
  if not exists (select 1 from public.profiles where id = 'e4444444-4444-4444-4444-444444444444'
                  and customer_type = 'wholesale_vip' and vip_approved_at is not null
                  and vip_approved_by = 'e8888888-8888-8888-8888-888888888888') then
    raise exception 'WA14 FAILED - profile not set to wholesale_vip with approval stamps';
  end if;
  select * into a from pg_temp.access_of('e4444444-4444-4444-4444-444444444444');
  if a.tier <> 'wholesale_vip' or a.vip_rows = 0 or (v_vip is not null and a.effective <> v_vip) then
    raise exception 'WA15 FAILED - approved customer: tier %, % VIP rows, effective %', a.tier, a.vip_rows, a.effective;
  end if;
  -- the application data is preserved
  if (select business_name from public.wholesale_access_requests where id = v_id) <> 'Assisted Holdings' then
    raise exception 'WA13 FAILED - application data not preserved';
  end if;
  raise notice 'WA13-15 ok - approval: row approved+stamped, profile wholesale_vip, VIP price % visible', a.effective;

  -- WA7 - approved = portal; re-deciding is refused ---------------------------
  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  v_err := null;
  begin perform public.admin_review_wholesale_request(v_id, 'rejected', 'late');
  exception when others then v_err := sqlerrm; end;
  perform pg_temp.as_postgres();
  if v_err not like 'not_pending%' then raise exception 'WA7 FAILED - approved application re-decided (%)', v_err; end if;
  raise notice 'WA7 ok - approved customer has the portal; a closed decision cannot be rewritten';

  -- WA16 - a customer cannot change status or tier from the client -----------
  select id into v_id from public.wholesale_access_requests where profile_id = 'e3333333-3333-3333-3333-333333333333';
  perform pg_temp.as_user('e3333333-3333-3333-3333-333333333333');
  v_err := null;
  begin update public.wholesale_access_requests set status = 'approved' where id = v_id;
  exception when others then v_err := sqlstate; end;
  if v_err is distinct from '42501' then raise exception 'WA16 FAILED - customer status update not refused (%)', v_err; end if;
  v_err := null;
  begin update public.profiles set customer_type = 'wholesale_vip' where id = 'e3333333-3333-3333-3333-333333333333';
  exception when others then v_err := sqlstate; end;
  if v_err is null then raise exception 'WA16 FAILED - customer wrote own customer_type'; end if;
  v_err := null;
  begin perform public.admin_review_wholesale_request(v_id, 'approved', null);
  exception when others then v_err := sqlstate; end;
  if v_err is distinct from '42501' then raise exception 'WA16 FAILED - customer approved own application (%)', v_err; end if;
  v_err := null;
  begin perform public.admin_set_customer_type('e3333333-3333-3333-3333-333333333333', 'wholesale_vip');
  exception when others then v_err := sqlstate; end;
  if v_err is distinct from '42501' then raise exception 'WA16 FAILED - customer granted own VIP (%)', v_err; end if;
  -- direct INSERT (installed builds) cannot set status either, even for one's own row
  perform pg_temp.as_user('e1111111-1111-1111-1111-111111111111');
  v_err := null;
  begin insert into public.wholesale_access_requests (profile_id, business_name, status)
        values ('e1111111-1111-1111-1111-111111111111', 'Forged', 'approved');
  exception when others then v_err := sqlstate; end;
  if v_err is distinct from '42501' then raise exception 'WA16 FAILED - direct insert with status not refused (%)', v_err; end if;
  perform pg_temp.as_postgres();
  if (select status from public.wholesale_access_requests where id = v_id) <> 'assistance_requested' then
    raise exception 'WA16 FAILED - status changed by the customer';
  end if;
  perform pg_temp.assert_no_portal('e3333333-3333-3333-3333-333333333333', 'WA16');
  raise notice 'WA16 ok - status UPDATE, customer_type write, self-approve, self-grant and forged insert all refused';

  -- WA17 - client-supplied status / tier / profile in the payload is ignored --
  perform pg_temp.as_user('e1111111-1111-1111-1111-111111111111');
  v_row := public.customer_save_wholesale_application(
    pg_temp.fields('Payload Tamper') || jsonb_build_object(
      'status', 'approved', 'customer_type', 'wholesale_vip',
      'profile_id', 'e7777777-7777-7777-7777-777777777777', 'reviewed_by', 'e8888888-8888-8888-8888-888888888888'),
    'submit');
  v_err := null;
  begin perform public.customer_save_wholesale_application(pg_temp.fields('x'), 'approve');
  exception when others then v_err := sqlstate; end;
  perform pg_temp.as_postgres();
  if v_row.status <> 'pending' or v_row.profile_id <> 'e1111111-1111-1111-1111-111111111111' or v_row.reviewed_by is not null then
    raise exception 'WA17 FAILED - tampered payload honoured: % % %', v_row.status, v_row.profile_id, v_row.reviewed_by;
  end if;
  if v_err is distinct from '22023' then raise exception 'WA17 FAILED - unknown action not refused (%)', v_err; end if;
  perform pg_temp.assert_no_portal('e1111111-1111-1111-1111-111111111111', 'WA17');
  raise notice 'WA17 ok - status/customer_type/profile_id/reviewed_by in the payload ignored; caller stays retail';

  -- WA18 - a non-approved applicant is charged retail by place_order() --------
  perform pg_temp.as_user('e3333333-3333-3333-3333-333333333333');
  v_result := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","quantity":1}]'::jsonb);
  perform pg_temp.as_postgres();
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  if v_item.tier_code_snapshot <> 'retail' or v_item.unit_price_cents <> v_retail then
    raise exception 'WA18 FAILED - applicant charged % at %', v_item.unit_price_cents, v_item.tier_code_snapshot;
  end if;
  raise notice 'WA18 ok - assistance-requested applicant ordered at retail (%)', v_item.unit_price_cents;

  -- WA19-WA20 - rejected customer resubmits; approval needed again ------------
  perform pg_temp.as_user('e6666666-6666-6666-6666-666666666666');
  v_row := public.customer_save_wholesale_application(pg_temp.fields('Rejected Mobile (Pvt) Ltd'), 'submit');
  perform pg_temp.as_postgres();
  if v_row.status <> 'pending' then raise exception 'WA19 FAILED - resubmission status %', v_row.status; end if;
  select count(*) into v_count from public.wholesale_access_requests
   where profile_id = 'e6666666-6666-6666-6666-666666666666' and status = 'rejected';
  if v_count <> 1 then raise exception 'WA19 FAILED - rejected decision not preserved'; end if;
  perform pg_temp.assert_no_portal('e6666666-6666-6666-6666-666666666666', 'WA20');
  -- and a second open application is refused
  perform pg_temp.as_user('e6666666-6666-6666-6666-666666666666');
  v_err := null;
  begin perform public.customer_save_wholesale_application(pg_temp.fields('Again'), 'submit');
  exception when others then v_err := sqlerrm; end;
  perform pg_temp.as_postgres();
  if v_err not like 'application_locked%' then raise exception 'WA19 FAILED - second submit: %', v_err; end if;
  raise notice 'WA19-20 ok - resubmitted as a new pending application, old rejection kept, still retail';

  -- Approval needs a business name; drafts cannot be decided.
  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  select id into v_id from public.wholesale_access_requests where profile_id = 'e2222222-2222-2222-2222-222222222222';
  v_err := null;
  begin perform public.admin_review_wholesale_request(v_id, 'approved', null);
  exception when others then v_err := sqlerrm; end;
  if v_err not like 'not_pending%' then raise exception 'WA20 FAILED - a draft was decided (%)', v_err; end if;
  perform pg_temp.as_postgres();
  perform pg_temp.as_user('e2222222-2222-2222-2222-222222222222');
  perform public.customer_save_wholesale_application('{}'::jsonb, 'assistance');
  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  v_err := null;
  begin perform public.admin_review_wholesale_request(v_id, 'approved', null);
  exception when others then v_err := sqlerrm; end;
  perform pg_temp.as_postgres();
  if v_err not like 'incomplete_application%' then raise exception 'WA20 FAILED - nameless approval: %', v_err; end if;
  perform pg_temp.assert_no_portal('e2222222-2222-2222-2222-222222222222', 'WA20');
  raise notice 'WA20 ok - drafts cannot be decided; approval without a business name refused';

  -- WA21-WA22 - existing VIP keeps working, and keeps VIP prices -------------
  select * into a from pg_temp.access_of('e7777777-7777-7777-7777-777777777777');
  if a.tier <> 'wholesale_vip' or a.vip_rows = 0 or (v_vip is not null and a.effective <> v_vip) then
    raise exception 'WA21/22 FAILED - existing VIP: tier %, % rows, effective %', a.tier, a.vip_rows, a.effective;
  end if;
  perform pg_temp.as_user('e7777777-7777-7777-7777-777777777777');
  v_result := pg_temp.place_order('[{"product_id":"iphone-17-pro-max","variant_key":"v1","quantity":1}]'::jsonb);
  v_err := null;
  begin perform public.customer_save_wholesale_application(pg_temp.fields('Dup'), 'submit');
  exception when others then v_err := sqlerrm; end;
  perform pg_temp.as_postgres();
  select * into v_item from public.order_items where order_id = (v_result ->> 'id')::uuid;
  if v_item.tier_code_snapshot <> 'wholesale_vip' or (v_vip is not null and v_item.unit_price_cents <> v_vip) then
    raise exception 'WA22 FAILED - existing VIP charged % at %', v_item.unit_price_cents, v_item.tier_code_snapshot;
  end if;
  if v_err not like 'already_wholesale%' then raise exception 'WA21 FAILED - VIP could apply again: %', v_err; end if;
  raise notice 'WA21-22 ok - pre-existing VIP: portal tier, VIP price % in catalog and checkout', v_item.unit_price_cents;

  -- WA23 - existing admin wholesale functionality ----------------------------
  -- The original pending-request decline path and the manual VIP grant still work.
  perform pg_temp.as_user('e8888888-8888-8888-8888-888888888888');
  select id into v_id from public.wholesale_access_requests
   where profile_id = 'e1111111-1111-1111-1111-111111111111' and status = 'pending';
  v_row := public.admin_review_wholesale_request(v_id, 'rejected', null);
  perform public.admin_set_customer_type('e1111111-1111-1111-1111-111111111111', 'wholesale_vip');
  perform public.admin_set_customer_type('e1111111-1111-1111-1111-111111111111', 'retail');
  perform pg_temp.as_postgres();
  if v_row.status <> 'rejected' then raise exception 'WA23 FAILED - decline path broken'; end if;
  perform pg_temp.assert_no_portal('e1111111-1111-1111-1111-111111111111', 'WA23 (revoked)');
  -- Legacy direct insert (installed builds): status defaults to pending and is stamped.
  perform pg_temp.as_user('e1111111-1111-1111-1111-111111111111');
  insert into public.wholesale_access_requests (profile_id, business_name) values ('e1111111-1111-1111-1111-111111111111', 'Legacy Build Ltd')
  returning * into v_row;
  perform pg_temp.as_postgres();
  if v_row.status <> 'pending' or v_row.submitted_at is null or v_row.customer_values ->> 'business_name' <> 'Legacy Build Ltd' then
    raise exception 'WA23 FAILED - legacy insert: % % %', v_row.status, v_row.submitted_at, v_row.customer_values;
  end if;
  raise notice 'WA23 ok - decline, manual VIP grant/revoke and legacy direct insert all still work';

  raise notice 'ALL WHOLESALE APPLICATION CHECKS PASSED';
end;
$$;

rollback;
