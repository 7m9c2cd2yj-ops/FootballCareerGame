#!/usr/bin/env bash
# Runs every GUT test under tests/ headless. Exit code 0 means all passed.
# Extra arguments are passed to GUT, e.g. -gselect=test_game_config.gd
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

# Importing first registers class_name scripts; without it a fresh clone
# fails to resolve global classes.
"$GODOT" --headless --import
"$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gexit "$@"
