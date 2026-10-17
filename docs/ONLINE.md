# Saves, sync, rankings and the ARENA

## Local saves (always on, offline)

`scripts/core/save/`. One career per slot (`free_save_slots` in
`data/game_config.json`, 3 for now). Each slot has:

| File | Meaning |
|---|---|
| `slot_N.json` | current save |
| `slot_N.backup.json` | the save before it |
| `slot_N.tmp.json` | only while writing |

- **Contents.** A save file holds the career plus a revision number, a
  timestamp, a summary for the slot list, and a **SHA-256 checksum**.
- **Writing.** The game writes the temporary file, reads it back and checks
  it. Then it removes the old backup, moves the current save to backup, and
  moves the temporary file to current. No step overwrites an existing file.
- **Loading.** The game considers current, temporary and backup, takes the
  newest one that is intact, migrates it to the latest format and checks it
  is valid. A damaged or tampered file falls back to the backup. A crash in
  the middle of a save is recovered from the temporary file. The tests
  simulate each of these cases.
- **Autosave** runs after every season, trial, transfer and retirement.

## Sync (when online)

- **What sync does.** After each autosave, `Backend.background_sync` uploads
  or downloads the slot. **Settings → Sync careers and rankings**
  does the same on demand.
- **Who wins.** `SyncPolicy` keeps the **newest valid** save: the copy
  further along (more seasons), then the later save, then the higher
  revision. The other copy is kept:
  - locally, as the slot's backup
  - on the server, in the `backup_envelope` column (a database trigger fills it)

  Neither copy is lost.
- **Order.** Syncs run one at a time, so overlapping autosaves never write a
  slot twice at once.
- **Offline.** Every online call returns a message instead of failing, and
  the career is never blocked.

## Rankings and the ARENA

- **Players can't write rankings.** Row-level security gives the client no
  insert or update rights on `rankings`.
- **The edge function does it.** `submit-ranking` reads the player's
  **uploaded career** (never a client-sent summary). It checks the career
  is one the game can produce (`plausibility.ts`): ages and seasons in step,
  overall changes within the game's real limits, trophies only in seasons
  when cups were held, awards only for seniors. It then **computes the
  summary itself** and writes the ranking.
- **The limits are pinned to the game.**
  - `limits.ts` mirrors the game data, and a test fails if they drift apart.
  - Real careers exported from the game (`backend/tests/fixtures`) must
    pass, and their summary must equal the game's own Hall of Fame summary.
- **The ARENA** shows each player's best career on your server, plus the
  all-time global list. Only preset display names appear (`data/preset_names.json`).

## Account deletion

**Settings → Delete my account** (tap twice) calls
`delete_my_account()`. It deletes the anonymous user, which cascades to the
profile, careers and rankings. Careers on the device stay, unless the player
also ticks "Also delete careers on this device".

## How it is tested

| Check | Command |
|---|---|
| Save system, sync decisions, request shapes | `./tools/run_tests.sh` (GUT) |
| Plausibility check, limits match game data, preset names and servers match the SQL | `node --experimental-strip-types --test backend/supabase/functions/submit-ranking/*.test.ts` |
| Migrations and row-level security on real Postgres, with a test-only stand-in for Supabase's `auth` schema | `backend/tests/run_sql_tests.sh` |
| The game's online client end to end against `tools/mock_supabase.py` | `./tools/test_online.sh` |

`./tools/test_backend.sh` runs the Node and SQL checks; CI runs all of them.
Setting up a real project: `docs/SUPABASE_SETUP.md`.
