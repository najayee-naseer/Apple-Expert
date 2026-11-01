-- ============================================================================
-- Apple Expert · counter checkout: price protection and duplicate requests
-- ----------------------------------------------------------------------------
-- WHY THIS IS A NEW FUNCTION AND NOT A CHANGE TO pos_create_sale
--   pos_create_sale stays exactly as it is: it prices on the server, moves stock
--   through the ledger and rolls back as a whole. pos_checkout wraps it and adds
--   what a cashier needs on top:
--
--   1. PRICES. The screen sends the price it showed for each line. That value is
--      only ever compared, never charged. Any difference stops the sale and
--      returns which items changed. The charged prices are also compared after
--      the sale, inside its transaction, so a price changed while the sale waited
--      for a lock rolls everything back instead of charging silently.
--
--   2. DUPLICATES. Requests with one id take turns on an advisory lock, before any
--      stock lock. A second request then finds the saved bill and returns it.
--      Without this it could wait on the stock lock and report "insufficient
--      stock" for a sale that had in fact just succeeded.
--
-- STALE DISCOUNT APPROVALS
--   pos_create_sale binds an approval to the items and the request, not the
--   subtotal, so an approval survived a price change. A trigger on pos_sales
--   closes that for every route into the table, without touching the function.
--
-- WHAT THIS DOES NOT TOUCH
--   No stock, price, sale, GRN or supplier row. move_stock, the ledger and the P1
--   guard are not replaced. pos_create_sale keeps its grant for older app builds.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Pre-flight
-- ----------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.pos_create_sale(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid)') is null then
    raise exception 'pre-flight: apply 20261101120000 first';
  end if;
  if to_regclass('public.product_barcodes') is null then
    raise exception 'pre-flight: apply 20261101140000 first';
  end if;
end
$$;


-- ----------------------------------------------------------------------------
-- 1. A discount approval is for the subtotal it was given on
-- ----------------------------------------------------------------------------
create or replace function private.guard_sale_discount_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approved bigint;
begin
  if new.discount_approval_id is not null
     and new.discount_approval_id is distinct from old.discount_approval_id then
    select a.subtotal_cents into v_approved from public.pos_discount_approvals a where a.id = new.discount_approval_id;
    if v_approved is distinct from new.subtotal_cents then
      raise exception 'discount_approval_stale: the bill changed after this discount was approved. Ask for approval again.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_sale_discount_approval() from public, anon, authenticated, service_role;

create trigger pos_sales_guard_discount_approval
  before update of discount_approval_id on public.pos_sales
  for each row execute function private.guard_sale_discount_approval();


-- ----------------------------------------------------------------------------
-- 2. Comparing prices
-- ----------------------------------------------------------------------------
-- p_expected is aligned with p_items: [{price_cents, tier_code}, ...].
create or replace function private.check_expected_prices(p_items jsonb, p_expected jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_line jsonb;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or p_expected is null or jsonb_typeof(p_expected) <> 'array'
     or jsonb_array_length(p_expected) <> jsonb_array_length(p_items) then
    raise exception 'invalid_expected_prices: send one displayed price for each item' using errcode = '22023';
  end if;
  for v_line in select value from jsonb_array_elements(p_expected) loop
    if jsonb_typeof(v_line) <> 'object' or coalesce(v_line ->> 'price_cents', '') !~ '^[0-9]{1,15}$' then
      raise exception 'invalid_expected_prices: a displayed price must be a whole number of cents' using errcode = '22023';
    end if;
  end loop;
end;
$$;

-- Which lines differ from what the screen showed. With p_sale_id, compares what
-- that sale charged; without, what would be charged now. A line that cannot be
-- resolved is skipped: pos_create_sale reports those with their own errors.
create or replace function private.pos_price_differences(p_items jsonb, p_expected jsonb, p_tier text, p_sale_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row      record;
  v_unit     public.inventory_units;
  v_product  text;
  v_variant  uuid;
  v_name     text;
  v_vname    text;
  v_previous bigint;
  v_current  bigint;
  v_tier     text;
  v_shown    text;
  v_changes  jsonb := '[]'::jsonb;
begin
  for v_row in select value as item, ordinality - 1 as idx from jsonb_array_elements(p_items) with ordinality loop
    v_unit := null;
    if v_row.item ? 'code' then
      select * into v_unit from private.find_unit_by_code(private.normalize_serial(v_row.item ->> 'code'));
      continue when v_unit.id is null;
      v_product := v_unit.product_id;
      v_variant := v_unit.variant_id;
    else
      v_product := v_row.item ->> 'product_id';
      begin
        v_variant := nullif(v_row.item ->> 'variant_id', '')::uuid;
      exception when invalid_text_representation then
        continue;
      end;
    end if;

    select p.name into v_name from public.products p where p.id = v_product;
    continue when not found;
    select v.name into v_vname from public.product_variants v where v.id = v_variant;

    if p_sale_id is null then
      select r.price_cents, r.tier_code into v_current, v_tier
        from private.resolve_price(v_product, v_variant, p_tier) r;
      if not found then
        v_current := null;
        v_tier := null;
      end if;
    else
      select i.unit_price_cents, i.tier_code_snapshot into v_current, v_tier
        from public.pos_sale_items i
       where i.pos_sale_id = p_sale_id
         and case when v_unit.id is not null then i.unit_id = v_unit.id
                  else i.unit_id is null and i.product_id = v_product and i.variant_id is not distinct from v_variant end;
    end if;

    v_previous := (p_expected -> v_row.idx ->> 'price_cents')::bigint;
    v_shown := p_expected -> v_row.idx ->> 'tier_code';
    if v_current is distinct from v_previous then
      v_changes := v_changes || jsonb_build_object(
        'code', v_unit.barcode,
        'product_id', v_product,
        'variant_id', v_variant,
        'product_name', v_name,
        'variant_name', v_vname,
        'previous_cents', v_previous,
        'current_cents', v_current,
        'current_tier', v_tier,
        'reason', case when v_current is null then 'price_removed'
                       when v_shown is distinct from v_tier then 'tier_changed'
                       else 'price_changed' end);
    end if;
  end loop;
  return v_changes;
end;
$$;

revoke all on function private.check_expected_prices(jsonb, jsonb) from public, anon, authenticated, service_role;
revoke all on function private.pos_price_differences(jsonb, jsonb, text, uuid) from public, anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 3. Asking before a discount request
-- ----------------------------------------------------------------------------
-- Read-only. Otherwise a discount would be approved against prices the screen does
-- not show, and the approval could never match the bill.
create or replace function public.pos_check_prices(p_items jsonb, p_expected_prices jsonb, p_customer_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  perform private.check_expected_prices(p_items, p_expected_prices);
  return private.pos_price_differences(p_items, p_expected_prices, private.tier_of_profile(p_customer_profile_id), null);
end;
$$;


-- ----------------------------------------------------------------------------
-- 4. Checkout
-- ----------------------------------------------------------------------------
create or replace function public.pos_checkout(
  p_items jsonb,
  p_payment_method text,
  p_payment_reference text,
  p_discount_cents bigint,
  p_customer_name text,
  p_customer_phone text,
  p_customer_profile_id uuid,
  p_note text,
  p_discount_approval_id uuid,
  p_request_id uuid,
  p_expected_prices jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier       text;
  v_changes    jsonb;
  v_result     jsonb;
  v_constraint text;
begin
  if (select auth.uid()) is null or not private.has_role('staff') then
    raise exception 'insufficient_privilege: staff role required' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  -- Same id: one at a time, before any stock lock. Held until this commits.
  perform pg_advisory_xact_lock(hashtextextended('pos_checkout:' || p_request_id::text, 0));

  -- Already saved: return that bill, or refuse a different one. The price it was
  -- sold at is history, so it is not compared again.
  if exists (select 1 from public.pos_sales s where s.request_id = p_request_id) then
    return public.pos_create_sale(p_items, p_payment_method, p_payment_reference, p_discount_cents, p_customer_name,
                                  p_customer_phone, p_customer_profile_id, p_note, p_discount_approval_id, p_request_id);
  end if;

  perform private.check_expected_prices(p_items, p_expected_prices);
  v_tier := private.tier_of_profile(p_customer_profile_id);

  v_changes := private.pos_price_differences(p_items, p_expected_prices, v_tier, null);
  if jsonb_array_length(v_changes) > 0 then
    raise exception 'price_changed: % changed price since it was added to this bill',
      jsonb_array_length(v_changes) || case when jsonb_array_length(v_changes) = 1 then ' item' else ' items' end
      using errcode = 'P0001', detail = v_changes::text;
  end if;

  begin
    v_result := public.pos_create_sale(p_items, p_payment_method, p_payment_reference, p_discount_cents, p_customer_name,
                                       p_customer_phone, p_customer_profile_id, p_note, p_discount_approval_id, p_request_id);
  exception when unique_violation then
    -- Only an older app calling pos_create_sale directly can get here first.
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint is distinct from 'pos_sales_request_id_key' then
      raise;
    end if;
    return public.pos_create_sale(p_items, p_payment_method, p_payment_reference, p_discount_cents, p_customer_name,
                                  p_customer_phone, p_customer_profile_id, p_note, p_discount_approval_id, p_request_id);
  end;

  if (v_result ->> 'replayed')::boolean then
    return v_result;
  end if;

  -- What was actually charged, under the stock locks. Raising undoes the whole sale.
  v_changes := private.pos_price_differences(p_items, p_expected_prices, v_tier, (v_result ->> 'id')::uuid);
  if jsonb_array_length(v_changes) > 0 then
    raise exception 'price_changed: % changed price while this sale was being saved',
      jsonb_array_length(v_changes) || case when jsonb_array_length(v_changes) = 1 then ' item' else ' items' end
      using errcode = 'P0001', detail = v_changes::text;
  end if;

  return v_result;
end;
$$;

comment on function public.pos_checkout(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid, jsonb) is
  'Staff. pos_create_sale, refusing any price the cashier did not see, and returning the saved bill to duplicate requests. Displayed prices are compared, never charged.';

revoke all on function public.pos_check_prices(jsonb, jsonb, uuid) from public, anon, service_role;
revoke all on function public.pos_checkout(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid, jsonb) from public, anon, service_role;
grant execute on function public.pos_check_prices(jsonb, jsonb, uuid) to authenticated;
grant execute on function public.pos_checkout(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid, jsonb) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. Self-verification
-- ----------------------------------------------------------------------------
do $$
begin
  if has_function_privilege('anon', 'public.pos_checkout(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid, jsonb)', 'EXECUTE')
     or has_function_privilege('anon', 'public.pos_check_prices(jsonb, jsonb, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.pos_price_differences(jsonb, jsonb, text, uuid)', 'EXECUTE') then
    raise exception 'verify: function grants are wrong';
  end if;
  raise notice 'verified: checkout is staff-only; no row was changed';
end
$$;


-- ----------------------------------------------------------------------------
-- Rollback (manual). Nothing stored depends on these.
--   drop function public.pos_checkout(jsonb, text, text, bigint, text, text, uuid, text, uuid, uuid, jsonb);
--   drop function public.pos_check_prices(jsonb, jsonb, uuid);
--   drop function private.pos_price_differences(jsonb, jsonb, text, uuid);
--   drop function private.check_expected_prices(jsonb, jsonb);
--   drop trigger pos_sales_guard_discount_approval on public.pos_sales;
--   drop function private.guard_sale_discount_approval();
-- ----------------------------------------------------------------------------
