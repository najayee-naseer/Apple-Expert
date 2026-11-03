#!/usr/bin/env bash
# ============================================================================
# Apple Expert - the 20 address limit under concurrent saves (LOCAL ONLY)
# ----------------------------------------------------------------------------
#   bash supabase/tests/verify_address_limit_concurrency.sh
#
# A customer with 18 saved addresses sends 6 saves at the same moment, each in
# its own session. save_address locks the customer's profile row before it
# counts, so exactly 2 may succeed and 4 must be refused with
# address_limit_reached, leaving exactly 20.
#
# Parallel sessions cannot share a transaction, so the fixture customer is
# committed, and deleted again on exit, pass or fail (addresses cascade).
# ============================================================================
set -euo pipefail

CONTAINER=supabase_db_apple-expert
CUSTOMER=da999999-9999-9999-9999-999999999999
PARALLEL=6
WORK="$(mktemp -d)"

if [ "$(docker inspect "$CONTAINER" --format '{{ index .Config.Labels "com.supabase.cli.project" }}' 2>/dev/null)" != "apple-expert" ]; then
  echo "REFUSED: $CONTAINER is not this project's local Supabase container" >&2
  exit 2
fi

as_postgres() { docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -qAt "$@"; }

cleanup() { echo "delete from auth.users where id = '$CUSTOMER';" | as_postgres >/dev/null 2>&1 || true; }
trap 'cleanup; rm -rf "$WORK"' EXIT

fail() { echo "FAILED - $*" >&2; exit 1; }

save_sql() { # $1 street  $2 seconds to hold the transaction open
  cat <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$CUSTOMER","role":"authenticated"}', true) \\g /dev/null
set local role authenticated;
select public.save_address(null, 'Home', 'Limit Customer', '+94771234567', 'Western Province', 'Colombo',
                           'Colombo', '$1', null, null, null, null, false);
select pg_sleep(${2:-0}) \\g /dev/null
commit;
SQL
}

cleanup
as_postgres >/dev/null <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data, is_super_admin)
values ('$CUSTOMER', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'da-limit@test.local', '',
        now(), now(), now(), '{}', '{}', false);
SQL
for i in $(seq 1 18); do
  save_sql "$i Fixture Road" | as_postgres >/dev/null
done
[ "$(echo "select count(*) from public.addresses where profile_id = '$CUSTOMER';" | as_postgres)" = 18 ] || fail "fixture did not reach 18"

# Every session starts together and holds its transaction open briefly, so the
# saves genuinely overlap.
for i in $(seq 1 "$PARALLEL"); do
  { if save_sql "Parallel $i Road" 0.3 | as_postgres > "$WORK/$i.out" 2>&1; then echo 0; else echo 1; fi > "$WORK/$i.code"; } &
done
wait

ok=0; limited=0
for i in $(seq 1 "$PARALLEL"); do
  if [ "$(cat "$WORK/$i.code")" = 0 ]; then ok=$((ok + 1))
  elif grep -q 'address_limit_reached' "$WORK/$i.out"; then limited=$((limited + 1))
  else fail "session $i failed for another reason: $(cat "$WORK/$i.out")"
  fi
done
total="$(echo "select count(*) from public.addresses where profile_id = '$CUSTOMER';" | as_postgres)"

echo "saved $ok, refused $limited, total $total"
[ "$ok" = 2 ] && [ "$limited" = $((PARALLEL - 2)) ] && [ "$total" = 20 ] || fail "the limit was not held under concurrency"
echo "ALL ADDRESS LIMIT CONCURRENCY CHECKS PASSED"
