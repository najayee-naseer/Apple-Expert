#!/usr/bin/env bash
# ============================================================================
# Apple Expert - reservation, POS and GRN concurrency checks (LOCAL ONLY)
# ----------------------------------------------------------------------------
# NOT YET EXECUTED: written with the migrations, for the database phase.
# Real parallel sessions through the API login (authenticator -> authenticated):
#
#   bash supabase/tests/verify_inventory_master_concurrency.sh
#
#   R1  two customers want the last unit at once     -> one order, one refusal
#   R2  a counter sale and an order for the last one -> one wins, never both
#   R3  the same order request twice at once         -> one order, one replay
#   R4  20 parallel orders across two products, in opposite line order
#                                                    -> no deadlock, none oversold
#   R5  a GRN and orders on the same product at once -> no deadlock, number honest
#   A   every other stock path, one at a time, as a non-operator session, so the P1
#       stock guard is armed: correction, supplier return and reversal, quantity
#       sale, customer return and release, pre-rollout shipment, online shipment,
#       expiry, quarantine and write-off. Then stock must equal the ledger's sum.
# ============================================================================
set -euo pipefail

CONTAINER=supabase_db_apple-expert
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; cleanup' EXIT

ADMIN=61111111-1111-1111-1111-111111111111
C1=62222222-2222-2222-2222-222222222222
C2=63333333-3333-3333-3333-333333333333
# Every order needs a delivery address; the fixture block gives each customer one.
ADDR="(select id from public.addresses where profile_id = auth.uid() limit 1)"

as_postgres() { docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -qAt "$@"; }
as_api()      { docker exec -i "$CONTAINER" psql -h 127.0.0.1 -U authenticator -d postgres -qAt "$@"; }

# Fixtures are committed: parallel sessions cannot share a transaction.
cleanup() { as_postgres < "$HERE/verify_inventory_fixtures_cleanup.sql" >/dev/null 2>&1 || true; }

session() { # $1 user  $2 call
  cat <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', true) \\g /dev/null
set local role authenticated;
select $2;
commit;
SQL
}

fail() { echo "FAILED - $*" >&2; exit 1; }

cleanup
as_postgres >/dev/null <<SQL
begin;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.email, '', now(), now(), now(), '{}', '{}', false
from (values ('$ADMIN', 'cc-admin@test.local'), ('$C1', 'cc-c1@test.local'), ('$C2', 'cc-c2@test.local')) as u(id, email);
insert into public.user_roles (profile_id, role) values ('$ADMIN', 'admin');
insert into public.addresses (profile_id, recipient_name, phone, province, district, city, line1, is_default)
select c.id::uuid, 'Test Recipient', '+94771234567', 'Western Province', 'Colombo', 'Colombo', '1 Test Street', true
from (values ('$C1'), ('$C2')) as c(id);
insert into public.products (id, name, category_id, subcategory, stock, is_active, tracking_mode)
select p.id, p.id, (select id from public.categories where slug = 'accessories'), 'Other Accessories', p.stock, true, p.mode
from (values ('cc-last', 1, 'quantity'), ('cc-a', 15, 'quantity'), ('cc-b', 15, 'quantity'), ('cc-unit', 0, 'unit'), ('cc-armed', 0, 'quantity')) as p(id, stock, mode);
insert into public.product_prices (product_id, tier_code, price_cents, min_qty, starts_at)
select p.id, 'retail', 1000, 1, now() - interval '1 day' from public.products p where p.id like 'cc-%';
commit;
SQL

available() { as_postgres -c "select available from public.catalog_availability() where product_id = '$1' and variant_id is null"; }

# R1 -------------------------------------------------------------------------
LAST='[{"product_id":"cc-last","quantity":1}]'
session "$C1" "public.place_order_v3('$LAST'::jsonb, $ADDR, null, gen_random_uuid())" | as_api > "$WORK/r1a" 2>&1 &
session "$C2" "public.place_order_v3('$LAST'::jsonb, $ADDR, null, gen_random_uuid())" | as_api > "$WORK/r1b" 2>&1 &
wait
[ "$(grep -l 'order_number' "$WORK/r1a" "$WORK/r1b" | wc -l | tr -d ' ')" = 1 ] || fail "R1 expected exactly one order: $(cat "$WORK/r1a" "$WORK/r1b")"
grep -q 'insufficient_stock' "$WORK/r1a" "$WORK/r1b" || fail "R1 expected insufficient_stock"
[ "$(available cc-last)" = 0 ] || fail "R1 availability $(available cc-last)"
echo "R1 ok - the last unit went to exactly one order"

# R2 -------------------------------------------------------------------------
as_postgres -c "update public.orders set status = 'cancelled' where profile_id in ('$C1', '$C2')" >/dev/null
[ "$(available cc-last)" = 1 ] || fail "R2 setup"
SALE="public.pos_create_sale('[{\"product_id\":\"cc-last\",\"quantity\":1}]'::jsonb, 'cash', null, 0, null, null, null, null, null, gen_random_uuid())"
session "$C1" "public.place_order_v3('$LAST'::jsonb, $ADDR, null, gen_random_uuid())" | as_api > "$WORK/r2a" 2>&1 &
session "$ADMIN" "$SALE" | as_api > "$WORK/r2b" 2>&1 &
wait
WON=0; grep -q 'order_number' "$WORK/r2a" && WON=$((WON + 1)); grep -q 'bill_number' "$WORK/r2b" && WON=$((WON + 1))
[ "$WON" = 1 ] || fail "R2 expected one winner, got $WON: $(cat "$WORK/r2a" "$WORK/r2b")"
echo "R2 ok - counter and online cannot both sell the last one"

# R3 -------------------------------------------------------------------------
RID="$(uuidgen | tr 'A-Z' 'a-z')"
SAME="public.place_order_v3('[{\"product_id\":\"cc-a\",\"quantity\":1}]'::jsonb, $ADDR, null, '$RID'::uuid)"
session "$C1" "$SAME" | as_api > "$WORK/r3a" 2>&1 &
session "$C1" "$SAME" | as_api > "$WORK/r3b" 2>&1 &
wait
[ "$(as_postgres -c "select count(*) from public.orders where request_id = '$RID'")" = 1 ] || fail "R3 duplicate order"
grep -q '"replayed": *true' "$WORK/r3a" "$WORK/r3b" || fail "R3 expected a replay: $(cat "$WORK/r3a" "$WORK/r3b")"
echo "R3 ok - one order, one replay"

# R4 -------------------------------------------------------------------------
as_postgres -c "update public.orders set status = 'cancelled' where profile_id in ('$C1', '$C2') and status <> 'cancelled'" >/dev/null
for i in $(seq 1 10); do
  session "$C1" "public.place_order_v3('[{\"product_id\":\"cc-a\",\"quantity\":1},{\"product_id\":\"cc-b\",\"quantity\":1}]'::jsonb, $ADDR, null, gen_random_uuid())" | as_api > "$WORK/r4a$i" 2>&1 &
  session "$C2" "public.place_order_v3('[{\"product_id\":\"cc-b\",\"quantity\":1},{\"product_id\":\"cc-a\",\"quantity\":1}]'::jsonb, $ADDR, null, gen_random_uuid())" | as_api > "$WORK/r4b$i" 2>&1 &
done
wait
! grep -l 'deadlock' "$WORK"/r4* >/dev/null 2>&1 || fail "R4 deadlock: $(grep -h deadlock "$WORK"/r4* | head -1)"
HELD="$(as_postgres -c "select coalesce(sum(quantity), 0) from public.stock_reservations where product_id = 'cc-a' and status = 'active'")"
[ "$HELD" -le 15 ] || fail "R4 oversold: $HELD held of 15"
[ "$(available cc-a)" = "$((15 - HELD))" ] || fail "R4 availability"
echo "R4 ok - no deadlock across opposite line orders, nothing oversold"

# R5 -------------------------------------------------------------------------
LINE='[{"product_id":"cc-unit","received_quantity":25,"unit_cost_cents":100}]'
session "$ADMIN" "public.admin_receive_goods('opening', null, null, null, null, false, null, current_date, null, '$LINE'::jsonb, gen_random_uuid())" | as_api > "$WORK/r5g1" 2>&1 &
session "$ADMIN" "public.admin_receive_goods('opening', null, null, null, null, false, null, current_date, null, '$LINE'::jsonb, gen_random_uuid())" | as_api > "$WORK/r5g2" 2>&1 &
for i in $(seq 1 5); do
  session "$C1" "public.place_order_v3('[{\"product_id\":\"cc-unit\",\"quantity\":1}]'::jsonb, $ADDR, null, gen_random_uuid())" | as_api > "$WORK/r5o$i" 2>&1 &
done
wait
! grep -l 'deadlock' "$WORK"/r5* >/dev/null 2>&1 || fail "R5 deadlock"
[ "$(as_postgres -c "select stock from public.products where id = 'cc-unit'")" = \
  "$(as_postgres -c "select count(*) from public.inventory_units where product_id = 'cc-unit' and status in ('in_stock', 'reserved')")" ] || fail "R5 number and units disagree"
echo "R5 ok - receiving and ordering together: no deadlock, number equals units"

# A --------------------------------------------------------------------------
# One API call that must succeed. The guard would raise stock_locked if any of
# these moved stock without its ledger row.
api() { # $1 user  $2 call
  local out
  out="$(session "$1" "$2" | as_api 2>&1)"
  if echo "$out" | grep -q 'ERROR'; then fail "A: $2 -> $(echo "$out" | grep -m1 ERROR)"; fi
  echo "$out"
}
armed_stock() { as_postgres -c "select stock from public.products where id = 'cc-armed'"; }
expect_stock() { [ "$(armed_stock)" = "$1" ] || fail "A $2: stock $(armed_stock), expected $1"; }

api "$ADMIN" "public.admin_save_supplier(null, 'CC Supplier', null, null, null, null, null, null, null, true)" >/dev/null
SUP="$(as_postgres -c "select id from public.suppliers where name = 'CC Supplier'")"

api "$ADMIN" "public.admin_receive_goods('supplier', '$SUP'::uuid, null, null, 'CC-1', false, null, current_date, null, '[{\"product_id\":\"cc-armed\",\"received_quantity\":12,\"rejected_quantity\":2,\"rejection_reason\":\"bad\",\"unit_cost_cents\":100}]'::jsonb, gen_random_uuid())" >/dev/null
expect_stock 10 "GRN accepted only"
LINE="$(as_postgres -c "select l.id from public.grn_lines l join public.grns g on g.id = l.grn_id where g.supplier_invoice = 'CC-1'")"

api "$ADMIN" "public.admin_correct_grn_line('$LINE'::uuid, null, 1, 'one was never here', gen_random_uuid())" >/dev/null
expect_stock 9 "GRN correction"

api "$ADMIN" "public.admin_create_supplier_return('$SUP'::uuid, current_date, 'credit', null, '[{\"grn_line_id\":\"$LINE\",\"quantity\":1}]'::jsonb, 'faulty', gen_random_uuid())" >/dev/null
expect_stock 8 "supplier return"
RET="$(as_postgres -c "select id from public.supplier_returns where supplier_id = '$SUP'")"
api "$ADMIN" "public.admin_reverse_supplier_return('$RET'::uuid, 'entered by mistake')" >/dev/null
expect_stock 9 "supplier return reversal"

api "$ADMIN" "public.pos_create_sale('[{\"product_id\":\"cc-armed\",\"quantity\":2}]'::jsonb, 'cash', null, 0, null, null, null, null, null, gen_random_uuid())" >/dev/null
expect_stock 7 "counter quantity sale"
SALE_ID="$(as_postgres -c "select pos_sale_id from public.pos_sale_items where product_id = 'cc-armed'")"
ITEM="$(as_postgres -c "select id from public.pos_sale_items where product_id = 'cc-armed'")"
api "$ADMIN" "public.admin_record_customer_return('pos', '$SALE_ID'::uuid, '[{\"line_id\":\"$ITEM\",\"quantity\":1,\"condition\":\"opened\"}]'::jsonb, null, gen_random_uuid())" >/dev/null
expect_stock 7 "customer return moves no stock"
LOT="$(as_postgres -c "select id from public.quarantine_lots where product_id = 'cc-armed'")"
api "$ADMIN" "public.admin_resolve_quarantine_lot('$LOT'::uuid, 1, 1, 0, 'checked and sealed')" >/dev/null
expect_stock 8 "quarantine release"

LEGACY="$(as_postgres -c "insert into public.orders (order_number, profile_id, customer_type_at_purchase, total_cents, status) values ('CC-LEGACY', '$C1', 'retail', 100, 'processing') returning id" | head -1)"
as_postgres -c "insert into public.order_items (order_id, product_id, product_name_snapshot, unit_price_cents, quantity, line_total_cents, tier_code_snapshot) values ('$LEGACY', 'cc-armed', 'x', 100, 1, 100, 'retail')" >/dev/null
api "$ADMIN" "(select 1) ; update public.orders set status = 'shipped' where id = '$LEGACY'" >/dev/null
expect_stock 7 "pre-rollout shipment"

ORDER="$(api "$C1" "public.place_order_v3('[{\"product_id\":\"cc-armed\",\"quantity\":1}]'::jsonb, $ADDR, null, gen_random_uuid()) ->> 'id'" | head -1)"
expect_stock 7 "an order holds, the number stays"
api "$ADMIN" "(select 1) ; update public.orders set status = 'shipped' where id = '$ORDER'" >/dev/null
expect_stock 6 "first shipment"
api "$ADMIN" "(select 1) ; update public.orders set status = 'cancelled' where id = '$ORDER'" >/dev/null
expect_stock 6 "cancel after shipping restores nothing"

ORDER="$(api "$C1" "public.place_order_v3('[{\"product_id\":\"cc-armed\",\"quantity\":1}]'::jsonb, $ADDR, null, gen_random_uuid()) ->> 'id'" | head -1)"
as_postgres -c "update public.orders set reservation_expires_at = now() - interval '1 minute' where id = '$ORDER'; update public.stock_reservations set expires_at = now() - interval '1 minute' where order_id = '$ORDER'" >/dev/null
api "$ADMIN" "public.expire_pending_orders(50)" >/dev/null
[ "$(as_postgres -c "select stock_state from public.orders where id = '$ORDER'")" = expired ] || fail "A expiry"
expect_stock 6 "expiry moves no stock"

[ "$(as_postgres -c "select sum(delta) from public.inventory_movements where product_id = 'cc-armed'")" = "$(armed_stock)" ] || fail "A ledger does not sum to stock"

UNITS="$(as_postgres -c "select array_agg(id) from (select id from public.inventory_units where product_id = 'cc-unit' and status = 'in_stock' order by fifo_seq limit 3) u")"
api "$ADMIN" "public.admin_quarantine_units('$UNITS'::uuid[], 'doubtful')" >/dev/null
api "$ADMIN" "public.admin_release_quarantine_units('$UNITS'::uuid[], 'verified')" >/dev/null
api "$ADMIN" "public.admin_write_off_units('$UNITS'::uuid[], 'damage', 'dropped')" >/dev/null
[ "$(as_postgres -c "select stock from public.products where id = 'cc-unit'")" = \
  "$(as_postgres -c "select count(*) from public.inventory_units where product_id = 'cc-unit' and status in ('in_stock', 'reserved')")" ] || fail "A unit number and units disagree"
echo "A ok - every remaining stock path passes the armed guard; stock equals the ledger"

echo "ALL INVENTORY CONCURRENCY CHECKS PASSED"
