-- Kickoff Legacy backend schema (Supabase / Postgres 15+).
-- Players sign in anonymously. Every table has row-level security: players
-- can read and write only their own rows, except `rankings`, which everyone
-- signed in can read but nobody can write directly. Rankings are written only
-- by the `submit-ranking` edge function (service role) after it has checked
-- the career server-side. Never trust the client.

-- Servers: groups of players shown together in the ARENA (a region or a
-- community room). Created by the operators, read by everyone signed in.
create table public.servers (
  id text primary key check (id ~ '^[a-z0-9_]{2,32}$'),
  name text not null,
  kind text not null check (kind in ('region', 'community'))
);

insert into public.servers (id, name, kind) values
  ('europe', 'Europe', 'region'),
  ('americas', 'Americas', 'region'),
  ('asia_pacific', 'Asia-Pacific', 'region'),
  ('africa_middle_east', 'Africa & Middle East', 'region');

-- The only display names allowed online (no free text for a young audience).
-- Must match data/preset_names.json (checked by tests).
create table public.allowed_names (
  name text primary key
);

insert into public.allowed_names (name) values
  ('SwiftFalcon'),
  ('BraveBadger'),
  ('CleverCurler'),
  ('RocketRaven'),
  ('TurboTortoise'),
  ('MightyMarmot'),
  ('SilverSparrow'),
  ('JollyJaguar'),
  ('NimbleNewt'),
  ('BoldBison'),
  ('CosmicCobra'),
  ('DashingDolphin'),
  ('EagerEagle'),
  ('FearlessFox'),
  ('HappyHawk'),
  ('IcyIbex'),
  ('KeenKoala'),
  ('LivelyLion'),
  ('MagicMoose'),
  ('NobleNarwhal'),
  ('OrbitOtter'),
  ('PlayfulPuma'),
  ('QuickQuail'),
  ('RadiantRhino'),
  ('SunnySeal'),
  ('TrickyTapir'),
  ('WildWombat'),
  ('ZippyZebra'),
  ('BouncyBeaver'),
  ('CheekyChameleon'),
  ('DizzyDingo'),
  ('FizzyFerret'),
  ('GoalieGecko'),
  ('HeaderHeron'),
  ('VolleyVole'),
  ('PassingPenguin'),
  ('SprintingStork'),
  ('CornerCrane'),
  ('TackleTurtle'),
  ('FlickFlamingo');

-- One profile per account: a preset display name and a server.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade default auth.uid(),
  display_name text not null references public.allowed_names (name),
  server_id text not null default 'europe' references public.servers (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Career saves: one row per account and slot. `envelope` is the game's save
-- envelope (career JSON + checksum). The previous upload is kept as a backup
-- by the trigger below, so a bad sync can always be undone.
create table public.careers (
  owner uuid not null references auth.users (id) on delete cascade default auth.uid(),
  slot smallint not null check (slot between 1 and 10),
  revision integer not null check (revision >= 0),
  saved_at timestamptz not null,
  season_count smallint not null check (season_count between 0 and 40),
  envelope jsonb not null check (octet_length(envelope::text) < 1048576),
  backup_envelope jsonb,
  backup_saved_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (owner, slot)
);

create function public.keep_career_backup() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.backup_envelope := old.envelope;
  new.backup_saved_at := old.saved_at;
  new.updated_at := now();
  return new;
end;
$$;

create trigger careers_keep_backup
  before update on public.careers
  for each row execute function public.keep_career_backup();

-- Rankings: written only by the submit-ranking edge function (service role).
create table public.rankings (
  owner uuid not null references auth.users (id) on delete cascade,
  slot smallint not null check (slot between 1 and 10),
  display_name text not null references public.allowed_names (name),
  server_id text not null references public.servers (id),
  position text not null check (position in ('GK', 'DEF', 'MID', 'FWD')),
  peak_overall smallint not null check (peak_overall between 1 and 99),
  seasons smallint not null check (seasons between 0 and 40),
  trophies smallint not null check (trophies >= 0),
  golden_balls smallint not null check (golden_balls >= 0),
  hof_score integer not null check (hof_score >= 0),
  inducted boolean not null,
  retired boolean not null,
  updated_at timestamptz not null default now(),
  primary key (owner, slot)
);

create index rankings_server_score on public.rankings (server_id, hof_score desc);
create index rankings_score on public.rankings (hof_score desc);

-- The ARENA: each player's best career (by Hall of Fame score).
-- security_invoker: the caller's row-level security applies.
create view public.arena_entries with (security_invoker = true) as
  select distinct on (owner)
    owner, display_name, server_id, position, peak_overall, seasons,
    trophies, golden_balls, hof_score, inducted, retired, updated_at
  from public.rankings
  order by owner, hof_score desc, slot;

-- Account deletion (required by both app stores): removes the auth user,
-- which cascades to profile, careers and rankings.
create function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- Row-level security.
alter table public.servers enable row level security;
alter table public.allowed_names enable row level security;
alter table public.profiles enable row level security;
alter table public.careers enable row level security;
alter table public.rankings enable row level security;

create policy "servers are readable" on public.servers
  for select to authenticated using (true);
create policy "names are readable" on public.allowed_names
  for select to authenticated using (true);

create policy "read own profile" on public.profiles
  for select to authenticated using (id = auth.uid());
create policy "create own profile" on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy "update own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "read own careers" on public.careers
  for select to authenticated using (owner = auth.uid());
create policy "create own careers" on public.careers
  for insert to authenticated with check (owner = auth.uid());
create policy "update own careers" on public.careers
  for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());
create policy "delete own careers" on public.careers
  for delete to authenticated using (owner = auth.uid());

create policy "rankings are readable" on public.rankings
  for select to authenticated using (true);
-- No insert/update/delete policies on rankings: clients cannot write them.

-- Table privileges (explicit, so the schema is safe whatever the defaults).
revoke all on public.servers, public.allowed_names, public.profiles,
  public.careers, public.rankings, public.arena_entries from anon, authenticated;
grant select on public.servers, public.allowed_names, public.rankings,
  public.arena_entries to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.careers to authenticated;
grant all on public.servers, public.allowed_names, public.profiles,
  public.careers, public.rankings to service_role;
grant select on public.arena_entries to service_role;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
revoke all on function public.keep_career_backup() from public, anon, authenticated;
