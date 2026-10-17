# Backend (Supabase)

| Path | What |
|---|---|
| `supabase/migrations/` | SQL schema, row-level security, `delete_my_account()` |
| `supabase/functions/submit-ranking/` | Edge function that checks a career server-side and writes its ranking (`plausibility.ts` is pure and unit-tested) |
| `tests/run_sql_tests.sh` | Applies the migrations to a throwaway local Postgres and runs `rls_test.sql` |
| `tests/supabase_stub.sql` | TEST ONLY stand-in for Supabase's `auth` schema and roles |
| `tests/fixtures/` | Real careers exported by `tools/export_test_careers.gd` |

Setup: `docs/SUPABASE_SETUP.md`. Design and tests: `docs/ONLINE.md`.
Credentials come from environment variables (see `../.env.example`) and are
never committed.
