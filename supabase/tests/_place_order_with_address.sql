-- ============================================================================
-- Test helper, included by the suites that place orders.
-- ----------------------------------------------------------------------------
-- An order now needs a delivery address, and those suites test pricing, warranty
-- and stock rather than addresses. These session-temporary functions keep their
-- calls short: they give the signed-in test customer an address if it has none,
-- then order through place_order_v3 as the app does. Nothing is left behind, and
-- the address itself is tested in verify_delivery_addresses.sql.
--
-- run_all_local.sh prepends this file. To run one such suite by hand:
--   cat _place_order_with_address.sql verify_warranty_orders.sql | docker exec -i supabase_db_apple-expert psql -U postgres -q
-- ============================================================================
create function pg_temp.fixture_address() returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  select id into v_id from public.addresses where profile_id = auth.uid() order by is_default desc limit 1;
  if v_id is null then
    v_id := public.save_address(null, 'Test', 'Test Recipient', '+94771234567', 'Western Province', 'Colombo',
                                'Colombo', '1 Test Street', null, null, null, null, true);
  end if;
  return v_id;
end;
$$;

create function pg_temp.place_order(p_lines jsonb, p_notes text default null) returns jsonb language sql as $$
  select public.place_order_v3(p_lines, pg_temp.fixture_address(), p_notes, gen_random_uuid())
$$;

create function pg_temp.place_order_v2(p_lines jsonb, p_notes text, p_request_id uuid) returns jsonb language sql as $$
  select public.place_order_v3(p_lines, pg_temp.fixture_address(), p_notes, p_request_id)
$$;
