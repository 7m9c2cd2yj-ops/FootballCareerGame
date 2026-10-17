# Kickoff Legacy (working title)

A mobile football career game for iOS and Android, built with Godot 4.7.
Start at age 8 in an academy and play one career to retirement, chasing the
Golden Ball and the Hall of Fame. No luck rolls, no rerolls, no energy
system: results come from your choices and your touch skill in 3D moments.

> **Unofficial fan game.** Not affiliated with, endorsed by or connected to
> any real club, league, federation or player. All names, clubs, crests and
> kits are fictional.

The working title lives in `data/game_config.json`. The launcher name in
`project.godot` (`application/config/name`) must match it, and a unit test
fails if they differ.

## Requirements

| Tool | Version | Why |
|------|---------|-----|
| Godot (standard, not .NET) | 4.7.2-stable | Engine and editor |
| GUT | 9.7.1 (vendored in `addons/gut`) | Unit tests |
| Python | 3.10+ | For gdtoolkit |
| gdtoolkit | 4.5.0 | `gdlint` and `gdformat` |

## Setup

```bash
git clone <this repo> && cd FootballCareerGame
# Linux x86_64: downloads Godot into .tools/ and pip-installs gdtoolkit.
./tools/install_tools.sh
# macOS/Windows: install Godot 4.7.2 yourself, then point the scripts at it:
#   export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
#   python3 -m pip install "gdtoolkit==4.5.0"
cp .env.example .env   # only for online features (docs/SUPABASE_SETUP.md)
```

Open the project in the editor with `godot -e` (or via the Godot project
manager). Press F5 to run. On desktop, mouse clicks emulate touch.

## Checks (run before every commit)

```bash
./tools/lint.sh            # gdformat --check + gdlint (use --fix to reformat)
./tools/run_tests.sh       # all GUT tests headless; exit code 0 = pass
./tools/check_project.sh   # compiles every script, boots the game headless
```

Backend and online checks (Node 22+, local Postgres 15+):

```bash
./tools/test_backend.sh    # edge function tests + SQL migrations and row-level security
./tools/test_online.sh     # the game's online client against tools/mock_supabase.py
```

Online features are optional; see `docs/SUPABASE_SETUP.md` to turn them on
and `docs/ONLINE.md` for saves, sync, rankings and the ARENA.

`run_tests.sh` and `check_project.sh` also fail on GDScript warnings and on
script errors outside tests, and never wait for keyboard input, so CI cannot
pass by accident or hang. `run_tests.sh` passes extra arguments to GUT, e.g.
`./tools/run_tests.sh -gselect=test_game_config.gd`.

To tune progression, edit `data/balance.json` and run
`./tools/balance_report.sh` to see whole-career rating curves. See `docs/BALANCE.md`.
The 3D key moments (penalty, free kick, one-on-one, save) are described in
`docs/MOMENTS.md`, with numbers in `data/moment_tuning.json`. Clubs, trials,
contracts, transfers, injuries and retirement are in `docs/CAREER.md`
(data: `data/clubs.json`, `data/career_rules.json`). The phone (Clubs, News,
agent Messages, the Kickfie feed, Cups) is in `docs/PHONE.md` (text:
`data/text_templates.json`). Cups and the Golden Ball are in `docs/CUPS.md`
(data: `data/nations.json`, `data/cups.json`).
The same three checks run in GitHub Actions (`.github/workflows/ci.yml`).

## Project layout

```
addons/gut/      Vendored GUT test framework (MIT, do not edit)
backend/         Supabase SQL migrations, edge function, SQL tests
data/            JSON data: config, clubs, nations, balance, text templates
docs/            Architecture, performance budget, privacy policy, checklists
scenes/          .tscn scenes: display and input only
scripts/app/     Autoloads (Session: data + active career; ScreenFit: UI scale)
scripts/core/    Pure game logic (no nodes, no scene tree): unit tested
scripts/core/moments/  Key-moment rules: resolvers, planner, season rating
scripts/core/career/   Clubs, offers, contracts, trials, fatigue, Hall of Fame
scripts/core/news/     Career events, text templates, agent advice, content rules
scripts/core/cups/     Nations, cup draws and simulation, Golden Ball
scripts/core/save/     Save slots (current + backup, checksums), career envelopes
scripts/core/online/   Supabase requests, sessions, backend config, sync policy
scripts/ui/phone/      The in-game phone and its feed apps
scripts/ui/      Scripts attached to scenes; thin layer over core
scripts/ui/moments/    3D moment stage, HUD and touch controllers
tests/unit/      GUT tests for core logic (files named test_*.gd)
tests/ui/        GUT smoke tests that instance scenes
tests/helpers/   Shared test code (career simulator, balance fixture)
tools/           Setup, lint, tests, project check, balance report
```

See `docs/ARCHITECTURE.md` for the rules that keep logic testable.
Static typing is enforced: `project.godot` treats untyped declarations as
errors, and `check_project.sh` compiles every script (`tools/compile_all.gd`)
to catch them.

## Roadmap

M1 scaffold, M2 data and progression, M3 3D moments, M4 contracts and the
Clubs app, M5 phone UI, M6 cups, M7 saves, backend and the ARENA, M8 polish.
Open work is tracked in `TODO.md`.
