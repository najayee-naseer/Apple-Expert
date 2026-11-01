-- ============================================================================
-- Apple Expert · correction to 20261101150000_pos_checkout
-- ----------------------------------------------------------------------------
-- WITH ORDINALITY numbers rows as bigint and jsonb -> needs an integer, so every
-- call of pos_checkout and pos_check_prices failed with "operator does not exist:
-- jsonb -> bigint". They failed before writing anything. Found by the test suites
-- before that migration reached anywhere but the local database. This replaces the
-- one function; no row, grant, or other function changes.
-- ============================================================================

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
  for v_row in select value as item, (ordinality - 1)::integer as idx from jsonb_array_elements(p_items) with ordinality loop
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

revoke all on function private.pos_price_differences(jsonb, jsonb, text, uuid) from public, anon, authenticated, service_role;
