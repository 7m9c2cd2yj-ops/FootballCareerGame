-- Row-level security and schema tests. Run by backend/tests/run_sql_tests.sh
-- after supabase_stub.sql and the migrations. Any failed check raises.
\set ON_ERROR_STOP 1

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b');

create function pg_temp.act_as(user_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', user_id)::text, false);
$$;

-- 1. A creates a profile with a preset name; free text is refused.
set role authenticated;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into public.profiles (display_name) values ('SwiftFalcon');
do $$ begin
  insert into public.profiles (id, display_name) values (auth.uid(), 'I am a free-text name');
  raise exception 'FAIL: free-text display name accepted';
exception when foreign_key_violation or unique_violation then null;
end $$;

-- 2. A cannot create a profile for B.
do $$ begin
  insert into public.profiles (id, display_name)
    values ('00000000-0000-0000-0000-00000000000b', 'BraveBadger');
  raise exception 'FAIL: profile created for another user';
exception when insufficient_privilege then null;
end $$;

-- 3. A uploads a career; a second upload keeps the first as backup.
insert into public.careers (slot, revision, saved_at, season_count, envelope)
  values (1, 1, now(), 3, '{"revision": 1}');
update public.careers set revision = 2, envelope = '{"revision": 2}', season_count = 4
  where slot = 1;
do $$ begin
  if (select backup_envelope ->> 'revision' from public.careers where slot = 1) <> '1' then
    raise exception 'FAIL: previous upload not kept as backup';
  end if;
end $$;

-- 4. Slot numbers and sizes are checked.
do $$ begin
  insert into public.careers (slot, revision, saved_at, season_count, envelope)
    values (99, 1, now(), 0, '{}');
  raise exception 'FAIL: slot 99 accepted';
exception when check_violation then null;
end $$;

-- 5. A cannot write rankings directly.
do $$ begin
  insert into public.rankings (owner, slot, display_name, server_id, position, peak_overall,
    seasons, trophies, golden_balls, hof_score, inducted, retired)
  values (auth.uid(), 1, 'SwiftFalcon', 'europe', 'FWD', 99, 32, 50, 30, 999, true, true);
  raise exception 'FAIL: client wrote a ranking';
exception when insufficient_privilege then null;
end $$;

-- 6. B sees none of A's careers and cannot change or delete them.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into public.profiles (display_name, server_id) values ('BraveBadger', 'americas');
do $$
declare
  changed integer;
begin
  if (select count(*) from public.careers) <> 0 then
    raise exception 'FAIL: B can read A''s careers';
  end if;
  update public.careers set revision = 99 where owner = '00000000-0000-0000-0000-00000000000a';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'FAIL: B updated A''s career'; end if;
  delete from public.careers where owner = '00000000-0000-0000-0000-00000000000a';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'FAIL: B deleted A''s career'; end if;
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'FAIL: B can read other profiles';
  end if;
end $$;

-- 7. The edge function (service role) writes rankings; everyone signed in reads them.
reset role;
set role service_role;
insert into public.rankings (owner, slot, display_name, server_id, position, peak_overall,
  seasons, trophies, golden_balls, hof_score, inducted, retired) values
  ('00000000-0000-0000-0000-00000000000a', 1, 'SwiftFalcon', 'europe', 'FWD', 95, 20, 3, 1, 150, true, false),
  ('00000000-0000-0000-0000-00000000000a', 2, 'SwiftFalcon', 'europe', 'MID', 80, 10, 0, 0, 90, false, false),
  ('00000000-0000-0000-0000-00000000000b', 1, 'BraveBadger', 'americas', 'GK', 88, 25, 1, 0, 120, false, true);
reset role;
set role authenticated;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
do $$ begin
  if (select count(*) from public.rankings) <> 3 then
    raise exception 'FAIL: rankings not readable';
  end if;
  if (select count(*) from public.arena_entries) <> 2 then
    raise exception 'FAIL: arena should list each player once';
  end if;
  if (select hof_score from public.arena_entries where display_name = 'SwiftFalcon') <> 150 then
    raise exception 'FAIL: arena should show the best career';
  end if;
end $$;

-- 8. Signed-out (anon) requests get nothing.
reset role;
set role anon;
do $$ begin
  perform count(*) from public.careers;
  raise exception 'FAIL: anon read careers';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.delete_my_account();
  raise exception 'FAIL: anon could call delete_my_account';
exception when insufficient_privilege then null;
end $$;

-- 9. Account deletion removes everything of A and nothing of B.
reset role;
set role authenticated;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select public.delete_my_account();
reset role;
do $$ begin
  if exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000a') then
    raise exception 'FAIL: auth user not deleted';
  end if;
  if exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-00000000000a')
     or exists (select 1 from public.careers where owner = '00000000-0000-0000-0000-00000000000a')
     or exists (select 1 from public.rankings where owner = '00000000-0000-0000-0000-00000000000a') then
    raise exception 'FAIL: deleted account left data behind';
  end if;
  if not exists (select 1 from public.rankings where owner = '00000000-0000-0000-0000-00000000000b') then
    raise exception 'FAIL: deletion touched another account';
  end if;
end $$;

select 'rls_test: all checks passed' as result;
