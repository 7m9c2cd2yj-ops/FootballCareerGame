# Supabase setup (online saves, rankings, ARENA)

The game is fully playable without this. Do these steps once to turn on
online sync, rankings and the ARENA. Dashboard menu names change from time
to time; if a label differs, look for the same setting nearby.

## 1. Create the project

1. Sign in at <https://supabase.com> and create a **new project**.
   - Choose a region close to your players (Europe for the `europe` server, and so on).
   - Set a strong database password and store it in your password manager.
2. Wait until the project shows as ready.

## 2. Allow anonymous sign-ins

Players never enter an email or password: the game signs in anonymously.

1. Open **Authentication → Sign In / Providers**.
2. Turn on **Allow anonymous sign-ins** and save.
3. Under **Authentication → Rate Limits**, keep the limit on anonymous
   sign-ins per IP low (the default is fine). This slows down abuse.
   The game does not use CAPTCHA yet (see `TODO.md`), so do **not** enable
   CAPTCHA protection now, or sign-in will fail.

## 3. Install the Supabase CLI and link the project

```bash
npm install -g supabase   # or: brew install supabase/tap/supabase
supabase login            # opens a browser to authorise the CLI
cd backend
supabase init             # creates supabase/config.toml; keeps the existing
                          # migrations/ and functions/ folders
supabase link --project-ref <your-project-ref>
```

The project ref is the `xxxx` in `https://xxxx.supabase.co`, also shown
under **Project Settings → General**. `link` asks for the database password
from step 1.

## 4. Create the database (migrations)

```bash
supabase db push          # from backend/
```

This applies `backend/supabase/migrations/*.sql`. It creates:
- the tables `servers`, `allowed_names`, `profiles`, `careers` and `rankings`
- the `arena_entries` view
- the `delete_my_account()` function
- every row-level security policy

To check, open **Table Editor**. Each table should show **RLS enabled**.
`rankings` has only a *select* policy, so clients can read it but not write it.

## 5. Deploy the ranking function

```bash
supabase functions deploy submit-ranking     # from backend/
```

The function reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, which
Supabase provides to edge functions automatically. **Never** copy the
service-role key into the game, `.env`, or any file in this repository.

## 6. Point the game at the project

1. Open **Project Settings → API Keys** (or **API**). Copy:
   - the **Project URL**, for example `https://xxxx.supabase.co`
   - the **anon** key (labelled `anon` / `public`, or the newer
     **publishable** key). This key is meant to be public, because
     row-level security protects the data.
2. In the repository root:
   ```bash
   cp .env.example .env      # if you have not already
   # edit .env: SUPABASE_URL=... and SUPABASE_ANON_KEY=...
   ./tools/write_backend_config.sh
   ```
   This writes `config/backend.local.json`, which git ignores. Builds that
   include it have online features. Builds without it play offline.

## 7. Check it works

1. Run the game (`godot -e`, F5).
2. Open **Settings**. The status should say online features are
   available.
3. Pick a name and server, then tap **Save name and server**. You should see
   "Profile saved."
4. Start a career and play two or three seasons (quick sim is fine). Each
   autosave also syncs in the background.
5. Back in **Settings**, tap **Sync careers and rankings**. Each slot
   should say "up to date" or "uploaded", then "Ranking updated."
6. Open **ARENA**. You should appear under **My server** and **Global**.
7. In the dashboard **Table Editor**:
   - `careers` has your save, and `backup_envelope` fills from the second upload.
   - `rankings` has your row.
8. **Account deletion:** in **Settings**, tap **Delete my account**
   twice. Your rows disappear from `profiles`, `careers` and `rankings`, and
   the anonymous user disappears from **Authentication → Users**.

## 8. Without a Supabase project

`./tools/test_online.sh` starts `tools/mock_supabase.py`, a local stand-in
with the same endpoints and owner-only rules, and runs the whole online flow
against it. To click through the online screens by hand without Supabase:

```bash
python3 tools/mock_supabase.py --port 54400 --anon-key dev-anon-key &
echo '{"url": "http://127.0.0.1:54400", "anon_key": "dev-anon-key"}' > /tmp/kl_backend.json
KL_BACKEND_CONFIG=/tmp/kl_backend.json godot
```

## Keys and security, in short

| Key | Where it may live |
|---|---|
| Project URL, anon/publishable key | `.env`, `config/backend.local.json`, the shipped game |
| Service-role key, database password | Supabase only (edge functions get it automatically) and your password manager. Never in the game or this repository. |

The anon key can't do anything that row-level security doesn't allow:
- players read and write only their own profile and careers
- rankings are read-only for players and written only by `submit-ranking`
  after it has checked the career
