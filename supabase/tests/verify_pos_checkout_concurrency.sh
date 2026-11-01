#!/usr/bin/env bash
# ============================================================================
# Apple Expert - counter checkout concurrency checks (LOCAL ONLY)
# ----------------------------------------------------------------------------
#   bash supabase/tests/verify_pos_checkout_concurrency.sh
#
# Real parallel sessions through the API login (authenticator -> authenticated),
# so the P1 stock guard is armed:
#
#   P1  ten first submissions with one id      -> one sale; all ten get that bill
#   P2  the same, for the last item in stock   -> no false "insufficient stock"
#   P3  ten retries of a saved bill            -> that bill, nothing sold
#   P4  one id, two different bills            -> one sale; the other is refused
#   P5  price changes while the sale waits     -> rolled back and reported
#   P6  one id mixed with direct older calls   -> one sale
# ============================================================================
set -euo pipefail

CONTAINER=supabase_db_apple-expert
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
STAFF=62222222-2222-2222-2222-222222222222

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
select set_config('request.jwt.claims', '{"sub":"$STAFF","role":"authenticated"}', true) \\g /dev/null
set local role authenticated;
select $1;
commit;
SQL
}
checkout() { # $1 items json, $2 expected json, $3 request id
  echo "public.pos_checkout('$1'::jsonb, 'cash', null, 0, null, null, null, null, null, '$3'::uuid, '$2'::jsonb)"
}
sales_for() { as_postgres -c "select count(*) from public.pos_sales where request_id = '$1'"; }
stock_of()  { as_postgres -c "select stock from public.products where id = '$1'"; }
ledger_of() { as_postgres -c "select coalesce(sum(delta), 0) from public.inventory_movements where product_id = '$1'"; }
same_bill() { # every session in $1* printed the one bill
  [ "$(grep -hoE '"bill_number": "POS-[0-9-]+"' "$1"* | sort -u | wc -l | tr -d ' ')" = 1 ] || return 1
  [ "$(grep -lE '"bill_number": "POS-' "$1"* | wc -l | tr -d ' ')" = "$2" ]
}

as_postgres < "$HERE/verify_inventory_fixtures_cleanup.sql" >/dev/null
as_postgres >/dev/null <<SQL
begin;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
values ('$STAFF', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cc-pc@test.local', '', now(), now(), now(), '{}', '{}', false);
insert into public.user_roles (profile_id, role) values ('$STAFF', 'staff');
insert into public.products (id, name, category_id, subcategory, stock, is_active)
select p.id, p.id, (select id from public.categories where slug = 'accessories'), 'Other Accessories', p.stock, true
from (values ('cc-many', 50), ('cc-last', 1), ('cc-race', 10), ('cc-mix', 10)) as p(id, stock);
insert into public.product_prices (product_id, tier_code, price_cents, min_qty, starts_at)
select id, 'retail', 1000, 1, now() - interval '1 day' from (values ('cc-many'), ('cc-last'), ('cc-race'), ('cc-mix')) as p(id);
commit;
SQL
EXPECT='[{"price_cents":1000,"tier_code":"retail"}]'

# P1 -------------------------------------------------------------------------
ID=$(uuidgen | tr 'A-Z' 'a-z'); ITEMS='[{"product_id":"cc-many","variant_id":null,"quantity":2}]'
for i in $(seq 1 10); do session "$(checkout "$ITEMS" "$EXPECT" "$ID")" | as_api > "$WORK/p1$i" 2>&1 & done
wait
[ "$(sales_for "$ID")" = 1 ] || fail "P1 sales"
same_bill "$WORK/p1" 10 || fail "P1 not all the same bill: $(cat "$WORK"/p1* | cut -c1-120 | sort -u)"
! grep -lE 'duplicate key|23505|deadlock' "$WORK"/p1* >/dev/null 2>&1 || fail "P1 raw error"
[ "$(grep -l '"replayed": false' "$WORK"/p1* | wc -l | tr -d ' ')" = 1 ] || fail "P1 expected exactly one first save"
[ "$(stock_of cc-many)" = 48 ] && [ "$(ledger_of cc-many)" = -2 ] || fail "P1 stock or ledger"
echo "P1 ok - ten first submissions, one sale, all got the same bill, no raw error"

# P2 -------------------------------------------------------------------------
ID=$(uuidgen | tr 'A-Z' 'a-z'); ITEMS='[{"product_id":"cc-last","variant_id":null,"quantity":1}]'
for i in $(seq 1 10); do session "$(checkout "$ITEMS" "$EXPECT" "$ID")" | as_api > "$WORK/p2$i" 2>&1 & done
wait
[ "$(sales_for "$ID")" = 1 ] || fail "P2 sales"
same_bill "$WORK/p2" 10 || fail "P2 false failure: $(cat "$WORK"/p2* | cut -c1-120 | sort -u)"
! grep -l 'insufficient_stock' "$WORK"/p2* >/dev/null 2>&1 || fail "P2 false shortage"
[ "$(stock_of cc-last)" = 0 ] && [ "$(ledger_of cc-last)" = -1 ] || fail "P2 stock or ledger"
echo "P2 ok - last item, one sale, no false shortage for the same request"

# P3 -------------------------------------------------------------------------
ID=$(uuidgen | tr 'A-Z' 'a-z'); ITEMS='[{"product_id":"cc-many","variant_id":null,"quantity":1}]'
session "$(checkout "$ITEMS" "$EXPECT" "$ID")" | as_api > "$WORK/p3first" 2>&1
BEFORE=$(stock_of cc-many); MOVES=$(as_postgres -c "select count(*) from public.inventory_movements where product_id = 'cc-many'")
for i in $(seq 1 10); do session "$(checkout "$ITEMS" "$EXPECT" "$ID")" | as_api > "$WORK/p3r$i" 2>&1 & done
wait
same_bill "$WORK/p3" 11 || fail "P3 bills: $(cat "$WORK"/p3* | cut -c1-120 | sort -u)"
[ "$(grep -l '"replayed": true' "$WORK"/p3r* | wc -l | tr -d ' ')" = 10 ] || fail "P3 replay marks"
[ "$(stock_of cc-many)" = "$BEFORE" ] || fail "P3 stock moved"
[ "$(as_postgres -c "select count(*) from public.inventory_movements where product_id = 'cc-many'")" = "$MOVES" ] || fail "P3 ledger moved"
echo "P3 ok - ten retries of a saved bill sold nothing"

# P4 -------------------------------------------------------------------------
ID=$(uuidgen | tr 'A-Z' 'a-z'); BEFORE=$(stock_of cc-many)
session "$(checkout '[{"product_id":"cc-many","variant_id":null,"quantity":1}]' "$EXPECT" "$ID")" | as_api > "$WORK/p4a" 2>&1 &
session "$(checkout '[{"product_id":"cc-many","variant_id":null,"quantity":3}]' "$EXPECT" "$ID")" | as_api > "$WORK/p4b" 2>&1 &
wait
[ "$(sales_for "$ID")" = 1 ] || fail "P4 sales"
[ "$(cat "$WORK/p4a" "$WORK/p4b" | grep -c 'request_id_reused')" -ge 1 ] || fail "P4 expected a refusal: $(cat "$WORK/p4a" "$WORK/p4b" | cut -c1-160)"
! grep -lE 'duplicate key|23505' "$WORK/p4a" "$WORK/p4b" >/dev/null 2>&1 || fail "P4 raw error"
SOLD=$(as_postgres -c "select quantity from public.pos_sale_items i join public.pos_sales s on s.id = i.pos_sale_id where s.request_id = '$ID'")
[ "$(stock_of cc-many)" = "$((BEFORE - SOLD))" ] || fail "P4 stock"
echo "P4 ok - one id, two bills: one sold ($SOLD), the other refused"

# P5 -------------------------------------------------------------------------
# A holds the product's row lock. B passes the first price check, then waits for
# that lock inside the sale. A changes the price and commits. B must not charge it.
ID=$(uuidgen | tr 'A-Z' 'a-z'); FIFO="$WORK/p5fifo"
as_postgres >/dev/null -c "select 1"
{
  docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -qAt <<SQL
begin;
select id from public.products where id = 'cc-race' for update;
select pg_sleep(2);
update public.product_prices set price_cents = 1500 where product_id = 'cc-race' and tier_code = 'retail';
commit;
SQL
} > "$FIFO.a" 2>&1 &
PID_A=$!
sleep 0.7
session "$(checkout '[{"product_id":"cc-race","variant_id":null,"quantity":1}]' "$EXPECT" "$ID")" | as_api > "$WORK/p5b" 2>&1
wait "$PID_A"
grep -q 'price_changed' "$WORK/p5b" || fail "P5 expected price_changed: $(cut -c1-200 "$WORK/p5b")"
grep -q 'current_cents": 1500' "$WORK/p5b" || fail "P5 detail: $(cut -c1-300 "$WORK/p5b")"
[ "$(sales_for "$ID")" = 0 ] || fail "P5 a sale was saved"
[ "$(stock_of cc-race)" = 10 ] && [ "$(ledger_of cc-race)" = 0 ] || fail "P5 stock or ledger moved"
echo "P5 ok - a price changed mid-sale rolled the whole sale back"

# P6 -------------------------------------------------------------------------
ID=$(uuidgen | tr 'A-Z' 'a-z'); ITEMS='[{"product_id":"cc-mix","variant_id":null,"quantity":1}]'
DIRECT="public.pos_create_sale('$ITEMS'::jsonb, 'cash', null, 0, null, null, null, null, null, '$ID'::uuid)"
for i in 1 2 3 4; do session "$(checkout "$ITEMS" "$EXPECT" "$ID")" | as_api > "$WORK/p6c$i" 2>&1 & done
for i in 1 2; do session "$DIRECT" | as_api > "$WORK/p6d$i" 2>&1 & done
wait
[ "$(sales_for "$ID")" = 1 ] || fail "P6 sales"
same_bill "$WORK/p6c" 4 || fail "P6 checkout answers: $(cat "$WORK"/p6c* | cut -c1-160 | sort -u)"
[ "$(stock_of cc-mix)" = 9 ] && [ "$(ledger_of cc-mix)" = -1 ] || fail "P6 stock or ledger"
echo "P6 ok - checkout is safe even alongside an older app's direct calls"

echo "ALL POS CHECKOUT CONCURRENCY CHECKS PASSED"
