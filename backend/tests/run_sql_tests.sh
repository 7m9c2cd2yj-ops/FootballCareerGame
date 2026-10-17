#!/usr/bin/env bash
# Tests the Supabase migrations and row-level security on a throwaway local
# Postgres (15+): stub of Supabase's auth schema, then every migration, then
# backend/tests/rls_test.sql. Needs initdb/pg_ctl/psql on PATH or PG_BIN set.
# Usage: backend/tests/run_sql_tests.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PG_BIN="${PG_BIN:-$(dirname "$(command -v initdb || ls /usr/lib/postgresql/*/bin/initdb | tail -1)")}"
WORK="$(mktemp -d /var/tmp/kl_sqltest.XXXXXX)"
PORT="${PG_TEST_PORT:-54331}"
RUN_AS=()
if [[ "$(id -u)" == "0" ]]; then
  # Postgres refuses to run as root; use an unprivileged account.
  chown nobody "$WORK"
  RUN_AS=(su -s /bin/bash nobody -c)
fi
run() {
  if [[ ${#RUN_AS[@]} -gt 0 ]]; then "${RUN_AS[@]}" "$*"; else bash -c "$*"; fi
}
cleanup() {
  run "$PG_BIN/pg_ctl -D $WORK/data -m immediate stop" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

run "$PG_BIN/initdb -D $WORK/data -U postgres -A trust" >/dev/null
run "$PG_BIN/pg_ctl -D $WORK/data -o '-k $WORK -p $PORT -c listen_addresses=' -l $WORK/log -w start" >/dev/null
PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q -X)
"${PSQL[@]}" -c "create database kl_test" >/dev/null
"${PSQL[@]}" -d kl_test -f "$HERE/supabase_stub.sql" >/dev/null
for migration in "$HERE"/../supabase/migrations/*.sql; do
  echo "migration: $(basename "$migration")"
  "${PSQL[@]}" -d kl_test -f "$migration" >/dev/null
done
"${PSQL[@]}" -d kl_test -t -A -f "$HERE/rls_test.sql"
