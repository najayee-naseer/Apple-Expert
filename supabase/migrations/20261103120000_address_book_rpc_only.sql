-- ============================================================================
-- Apple Expert · the address book is written only through its functions
-- ----------------------------------------------------------------------------
-- 20261101160000 added save_address, set_default_address and delete_address, but
-- "addresses own all" and the table grants still let a customer insert, update
-- and delete their own rows through the API. The validation trigger covered those
-- writes; the rules that live in the functions did not: the duplicate check, the
-- first address becoming the default, the default passing on when it is deleted,
-- and one change at a time per customer.
--
-- What it changes
--   * authenticated loses INSERT, UPDATE and DELETE on public.addresses. SELECT
--     stays, because the app lists addresses with a plain read.
--   * "addresses own all" becomes "addresses read own", SELECT only, so a grant
--     restored by mistake still opens no write.
--   * save_address refuses a 21st address with address_limit_reached. The count
--     runs after the lock on the customer's profile row that every address book
--     function already takes, so two saves at once cannot both pass it.
--
-- The three functions are SECURITY DEFINER and owned by postgres, so they keep
-- writing. No row is changed. Rows already over the limit, if any, are kept; the
-- customer just cannot add another until they are under it.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Writes only through the functions
-- ----------------------------------------------------------------------------
revoke insert, update, delete on public.addresses from authenticated;

drop policy "addresses own all" on public.addresses;

create policy "addresses read own" on public.addresses
  for select to authenticated
  using (profile_id = (select auth.uid()));

-- ----------------------------------------------------------------------------
-- 2. At most 20 saved addresses per customer
-- ----------------------------------------------------------------------------
-- As in 20261101160000, with the limit added after the duplicate check, so a
-- customer re-saving an address they already have hears that instead.
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
  c_limit   constant integer := 20;
  v_uid     uuid := (select auth.uid());
  v_default boolean := coalesce(p_make_default, false);
  v_id      uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to save an address' using errcode = '42501';
  end if;

  -- One address book change at a time per customer. The limit below relies on it.
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

  -- Only a new address counts against the limit; editing one never does.
  if p_id is null and (select count(*) from public.addresses where profile_id = v_uid) >= c_limit then
    raise exception 'address_limit_reached: you can save up to % addresses. Delete one to add another', c_limit
      using errcode = 'P0001';
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

-- create or replace keeps the existing grants; restated so this file stands alone.
revoke all on function public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text) from public, anon, service_role;
grant execute on function public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 3. Verification
-- ----------------------------------------------------------------------------
do $$
declare
  v_fn text;
begin
  if has_table_privilege('authenticated', 'public.addresses', 'INSERT')
     or has_table_privilege('authenticated', 'public.addresses', 'UPDATE')
     or has_table_privilege('authenticated', 'public.addresses', 'DELETE')
     or has_table_privilege('anon', 'public.addresses', 'INSERT')
     or has_table_privilege('anon', 'public.addresses', 'UPDATE')
     or has_table_privilege('anon', 'public.addresses', 'DELETE') then
    raise exception 'client roles must not write public.addresses directly';
  end if;
  if not has_table_privilege('authenticated', 'public.addresses', 'SELECT') then
    raise exception 'authenticated must still read public.addresses';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'addresses' and cmd <> 'SELECT') then
    raise exception 'public.addresses must have no write policy';
  end if;

  foreach v_fn in array array[
    'public.save_address(uuid, text, text, text, text, text, text, text, text, text, text, text, boolean, text)',
    'public.set_default_address(uuid)',
    'public.delete_address(uuid)'
  ] loop
    if not (select p.prosecdef and pg_get_userbyid(p.proowner) = 'postgres' from pg_proc p where p.oid = v_fn::regprocedure) then
      raise exception '% must be SECURITY DEFINER and owned by postgres', v_fn;
    end if;
    if not has_function_privilege('authenticated', v_fn, 'EXECUTE')
       or has_function_privilege('anon', v_fn, 'EXECUTE') then
      raise exception '% must be executable by authenticated only', v_fn;
    end if;
  end loop;

  raise notice 'verified: address book writes only through its functions, 20 address limit';
end;
$$;

-- Rollback (manual, if ever needed): restore 20261101160000's save_address, then
--   drop policy "addresses read own" on public.addresses;
--   create policy "addresses own all" on public.addresses for all to authenticated
--     using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
--   grant insert, update, delete on public.addresses to authenticated;
