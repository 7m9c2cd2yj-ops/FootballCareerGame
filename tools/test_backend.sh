#!/usr/bin/env bash
# Backend checks: the edge function's TypeScript tests (Node 22+) and the SQL
# migrations + row-level security tests (local Postgres 15+).
set -euo pipefail
cd "$(dirname "$0")/.."
node --experimental-strip-types --test backend/supabase/functions/submit-ranking/*.test.ts
backend/tests/run_sql_tests.sh
