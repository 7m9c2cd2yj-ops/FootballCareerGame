-- TEST ONLY. A minimal stand-in for what Supabase provides, so the migrations
-- and row-level security can be tested on plain Postgres. Never run this
-- against a real Supabase project (it already has all of this).
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);
-- Like Supabase: the signed-in user's id comes from the request's JWT claims.
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
