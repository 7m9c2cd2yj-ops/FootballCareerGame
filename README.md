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
cp .env.example .env   # only needed from M7 (backend)
```

Open the project in the editor with `godot -e` (or via the Godot project
manager). Press F5 to run. On desktop, mouse clicks emulate touch.

## Checks (run before every commit)

```bash
./tools/lint.sh            # gdformat --check + gdlint (use --fix to reformat)
./tools/run_tests.sh       # all GUT tests headless; exit code 0 = pass
./tools/check_project.sh   # compiles every script, boots the game headless
```

`run_tests.sh` passes extra arguments to GUT, e.g.
`./tools/run_tests.sh -gselect=test_game_config.gd`.
The same three checks run in GitHub Actions (`.github/workflows/ci.yml`).

## Project layout

```
addons/gut/      Vendored GUT test framework (MIT, do not edit)
backend/         Supabase SQL migrations and edge functions (M7)
data/            JSON data: config, clubs, nations, balance, text templates
docs/            Architecture, performance budget, privacy policy, checklists
scenes/          .tscn scenes: display and input only
scripts/core/    Pure game logic (no nodes, no scene tree): unit tested
scripts/ui/      Scripts attached to scenes; thin layer over core
tests/unit/      GUT tests (files named test_*.gd)
tools/           Shell scripts for setup, lint, tests, project check
```

See `docs/ARCHITECTURE.md` for the rules that keep logic testable.
Static typing is enforced: `project.godot` treats untyped declarations as
errors, and `check_project.sh` compiles every script to catch them.

## Roadmap

M1 scaffold, M2 data and progression, M3 3D moments, M4 contracts and the
Clubs app, M5 phone UI, M6 cups, M7 saves, backend and the ARENA, M8 polish.
Open work is tracked in `TODO.md`.
