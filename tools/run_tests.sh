#!/usr/bin/env bash
# Runs every GUT test under tests/ headless. Exit code 0 means all passed.
# Extra arguments are passed to GUT, e.g. -gselect=test_game_config.gd
#
# Godot's exit code alone is not trusted: with -d, a script error outside a
# test (e.g. in an autoload) opens the debugger, and with stdin closed the run
# can stop early yet exit 0. So the run must also print GUT's success line
# and no script/parse errors.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

# Importing first registers class_name scripts; without it a fresh clone
# fails to resolve global classes.
"$GODOT" --headless --import < /dev/null

log="$(mktemp)"
status=0
"$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gexit "$@" < /dev/null 2>&1 | tee "$log" \
  || status=$?
if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi
if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
  echo "run_tests: script errors outside the tests (see above)" >&2
  exit 1
fi
if ! grep -q "All tests passed" "$log"; then
  echo "run_tests: GUT did not report success; the run may have stopped early" >&2
  exit 1
fi
