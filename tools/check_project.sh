#!/usr/bin/env bash
# 1) Compiles every one of our scripts (tools/compile_all.gd), so warnings the
#    project treats as errors (e.g. untyped declarations) fail even in scripts
#    no test loads yet, and fails on any other GDScript warning in them.
# 2) Boots the game headless for a few hundred frames and fails on any script
#    or engine error in the output (Godot exits 0 on most runtime errors).
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

"$GODOT" --headless --import < /dev/null

folders=()
for dir in "${GD_SOURCE_DIRS[@]}"; do
  folders+=("res://$dir")
done
compile_log="$(mktemp)"
# -d (debug) is what makes Godot report GDScript warnings.
"$GODOT" --headless -d -s tools/compile_all.gd -- "${folders[@]}" < /dev/null 2>&1 | tee "$compile_log"
if grep -A1 "^WARNING:" "$compile_log" | grep -qE "at: .*res://(scripts|tests|tools)/"; then
  echo "check_project: GDScript warnings in our scripts (see above)" >&2
  exit 1
fi

log="$(mktemp)"
"$GODOT" --headless --quit-after 300 < /dev/null 2>&1 | tee "$log"
if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load" "$log"; then
  echo "check_project: errors found while running the project" >&2
  exit 1
fi
echo "check_project: game booted and ran 300 frames without errors"
