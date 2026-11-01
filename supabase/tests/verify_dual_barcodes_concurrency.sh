#!/usr/bin/env bash
# ============================================================================
# Apple Expert - dual barcode concurrency checks (LOCAL ONLY)
# ----------------------------------------------------------------------------
#   bash supabase/tests/verify_dual_barcodes_concurrency.sh
#
# Real parallel sessions through the API login (authenticator -> authenticated),
# so the P1 stock guard is armed:
#
#   B1  eight sessions issue a code for one item   -> one code
#   B2  two items race to register one EAN         -> exactly one wins
#   B3  two tills sell the last item from a scan   -> exactly one sale
#   B4  twenty sessions issue for twenty items     -> twenty distinct codes
# ============================================================================
set -euo pipefail

CONTAINER=supabase_db_apple-expert
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
ADMIN=61111111-1111-1111-1111-111111111111

[ "$(docker inspect "$CONTAINER" --format '{{ index .Config.Labels "com.supabase.cli.project" }}')" = apple-expert ] \
  || { echo "REFUSED: not this project's local container" >&2; exit 2; }

as_postgres() { docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -qAt "$@"; }
as_api()      { docker exec -i "$CONTAINER" psql -h 127.0.0.1 -U authenticator -d postgres -qAt "$@"; }
cleanup()     { as_postgres < "$HERE/verify_inventory_fixtures_cleanup.sql" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
fail()        { echo "FAILED - $*" >&2; exit 1; }

session() { # $1 call
  cat <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$ADMIN","role":"authenticated"}', true) \\g /dev/null
set local role authenticated;
select $1;
commit;
SQL
}

as_postgres < "$HERE/verify_inventory_fixtures_cleanup.sql" >/dev/null
as_postgres >/dev/null <<SQL
begin;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
values ('$ADMIN', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cc-bc@test.local', '', now(), now(), now(), '{}', '{}', false);
insert into public.user_roles (profile_id, role) values ('$ADMIN', 'admin');
insert into public.products (id, name, category_id, subcategory, stock, is_active)
select p.id, p.id, (select id from public.categories where slug = 'accessories'), 'Other Accessories', p.stock, true
from (values ('cc-one', 0), ('cc-x', 0), ('cc-y', 0), ('cc-last', 1)) as p(id, stock);
insert into public.products (id, name, category_id, subcategory, stock, is_active)
select 'cc-many-' || n, 'many', (select id from public.categories where slug = 'accessories'), 'Other Accessories', 0, true
from generate_series(1, 20) n;
insert into public.product_prices (product_id, tier_code, price_cents, min_qty, starts_at)
values ('cc-last', 'retail', 1000, 1, now() - interval '1 day');
commit;
SQL

# B1 -------------------------------------------------------------------------
for i in 1 2 3 4 5 6 7 8; do
  session "public.admin_issue_product_barcode('cc-one', null) ->> 'value'" | as_api > "$WORK/b1$i" 2>&1 &
done
wait
[ "$(as_postgres -c "select count(*) from public.product_barcodes where product_id = 'cc-one'")" = 1 ] || fail "B1 more than one code"
[ "$(cat "$WORK"/b1* | sort -u | wc -l | tr -d ' ')" = 1 ] || fail "B1 sessions disagree: $(cat "$WORK"/b1* | sort -u)"
echo "B1 ok - eight parallel requests, one code"

# B2 -------------------------------------------------------------------------
session "public.admin_register_manufacturer_barcode('cc-x', null, '4006381333931')" | as_api > "$WORK/b2a" 2>&1 &
session "public.admin_register_manufacturer_barcode('cc-y', null, '4006381333931')" | as_api > "$WORK/b2b" 2>&1 &
wait
[ "$(as_postgres -c "select count(*) from public.product_barcodes where value = '4006381333931'")" = 1 ] || fail "B2 registered twice"
grep -qE 'barcode_in_use|duplicate key' "$WORK/b2a" "$WORK/b2b" || fail "B2 expected one refusal: $(cat "$WORK/b2a" "$WORK/b2b")"
! grep -l 'deadlock' "$WORK"/b2* >/dev/null 2>&1 || fail "B2 deadlock"
echo "B2 ok - one EAN, one owner"

# B3 -------------------------------------------------------------------------
SALE="public.pos_create_sale('[{\"product_id\":\"cc-last\",\"variant_id\":null,\"quantity\":1}]'::jsonb, 'cash', null, 0, null, null, null, null, null, gen_random_uuid())"
session "$SALE" | as_api > "$WORK/b3a" 2>&1 &
session "$SALE" | as_api > "$WORK/b3b" 2>&1 &
wait
WON=0; grep -q 'bill_number' "$WORK/b3a" && WON=$((WON + 1)); grep -q 'bill_number' "$WORK/b3b" && WON=$((WON + 1))
[ "$WON" = 1 ] || fail "B3 expected one sale, got $WON: $(cat "$WORK/b3a" "$WORK/b3b")"
[ "$(as_postgres -c "select stock from public.products where id = 'cc-last'")" = 0 ] || fail "B3 stock"
[ "$(as_postgres -c "select sum(delta) from public.inventory_movements where product_id = 'cc-last'")" = -1 ] || fail "B3 ledger"
echo "B3 ok - two tills, one last item, one sale"

# B4 -------------------------------------------------------------------------
for i in $(seq 1 20); do
  session "public.admin_issue_product_barcode('cc-many-$i', null) ->> 'value'" | as_api > "$WORK/b4$i" 2>&1 &
done
wait
[ "$(cat "$WORK"/b4* | grep -c '^AP')" = 20 ] || fail "B4 expected 20 codes"
[ "$(cat "$WORK"/b4* | sort -u | wc -l | tr -d ' ')" = 20 ] || fail "B4 duplicate codes"
echo "B4 ok - twenty parallel issues, twenty distinct codes"

echo "ALL DUAL BARCODE CONCURRENCY CHECKS PASSED"
