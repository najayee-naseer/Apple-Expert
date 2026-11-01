#!/usr/bin/env bash
# ============================================================================
# Runs every SQL suite against the LOCAL Supabase container, and proves the
# local data is unchanged afterwards.
#
#   bash supabase/tests/run_all_local.sh [output-dir]
#
# This repo is linked to a remote project and .env.local points at it, so nothing
# here uses the CLI or those settings: it talks only to the named Docker container,
# after checking the label that ties the container to this project. It never stops
# at a failure, and fixture cleanup runs after every suite, pass or fail.
# ============================================================================
set -u

CONTAINER=supabase_db_apple-expert
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$(mktemp -d)}"
mkdir -p "$OUT"

if [ "$(docker inspect "$CONTAINER" --format '{{ index .Config.Labels "com.supabase.cli.project" }}' 2>/dev/null)" != "apple-expert" ]; then
  echo "REFUSED: $CONTAINER is not this project's local Supabase container" >&2
  exit 2
fi

psql_pg() { docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -q "$@"; }

# Row count of every public and auth.users table, plus the catalog's stock values.
snapshot() {
  psql_pg -At <<'SQL'
select t.table_name, (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', t.table_name), false, true, '')))[1]::text
  from information_schema.tables t
 where t.table_schema = 'public' and t.table_type = 'BASE TABLE' order by 1;
select 'auth.users', count(*) from auth.users;
select 'stock_hash', md5(string_agg(id || ':' || stock, ',' order by id)) from public.products;
select 'variant_hash', md5(string_agg(id::text || ':' || coalesce(stock::text, '-'), ',' order by id)) from public.product_variants;
SQL
}

snapshot > "$OUT/baseline.txt"

declare -a SUITES=(
  "verify.sql|ALL CHECKS PASSED"
  "verify_warranty_orders.sql|ALL WARRANTY/ORDER CHECKS PASSED"
  "verify_variant_conditions.sql|ALL VARIANT CONDITION CHECKS PASSED"
  "verify_wholesale_applications.sql|ALL WHOLESALE APPLICATION CHECKS PASSED"
  "verify_inventory_ledger.sql|ALL INVENTORY LEDGER CHECKS PASSED"
  "verify_inventory_ledger_authenticator.sql|ALL AUTHENTICATOR STOCK GUARD CHECKS PASSED"
  "verify_grn_units_pos.sql|ALL GRN / UNIT / POS CHECKS PASSED"
  "verify_purchase_returns.sql|ALL PURCHASE & RETURNS CHECKS PASSED"
  "verify_inventory_master.sql|ALL INVENTORY MASTER CHECKS PASSED"
  "verify_dual_barcodes.sql|ALL DUAL BARCODE CHECKS PASSED"
  "verify_pos_checkout.sql|ALL POS CHECKOUT CHECKS PASSED"
)

FAILED=0
for entry in "${SUITES[@]}"; do
  suite="${entry%%|*}"
  marker="${entry##*|}"
  log="$OUT/${suite%.sql}.log"
  psql_pg < "$HERE/$suite" > "$log" 2>&1
  code=$?
  # After every suite, so a failed run cannot leave fixtures for the next one.
  psql_pg < "$HERE/verify_inventory_ledger_authenticator_cleanup.sql" > /dev/null 2>&1
  psql_pg < "$HERE/verify_inventory_fixtures_cleanup.sql" > /dev/null 2>&1
  cleanup=$?
  if [ "$code" = 0 ] && grep -qF "$marker" "$log"; then
    echo "PASS  $suite (exit $code, cleanup $cleanup)"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL  $suite (exit $code, cleanup $cleanup): $(grep -m1 -E 'ERROR|FAILED' "$log" | cut -c1-200)"
  fi
done

snapshot > "$OUT/after.txt"
if diff "$OUT/baseline.txt" "$OUT/after.txt" > "$OUT/data-diff.txt"; then
  echo "DATA  unchanged after the run"
else
  FAILED=$((FAILED + 1))
  echo "DATA  CHANGED:"; cat "$OUT/data-diff.txt"
fi

echo "failed: $FAILED   logs: $OUT"
[ "$FAILED" = 0 ]
