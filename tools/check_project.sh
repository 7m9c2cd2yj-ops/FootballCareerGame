#!/usr/bin/env bash
# 1) Compiles every one of our scripts (tools/compile_all.gd), so warnings the
#    project treats as errors (e.g. untyped declarations) fail even in scripts
#    no test loads yet.
# 2) Boots the game headless for a few hundred frames and fails on any script
#    or engine error in the output (Godot exits 0 on most runtime errors).
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

"$GODOT" --headless --import

folders=()
for dir in "${GD_SOURCE_DIRS[@]}"; do
  folders+=("res://$dir")
done
"$GODOT" --headless -s tools/compile_all.gd -- "${folders[@]}"

log="$(mktemp)"
"$GODOT" --headless --quit-after 300 2>&1 | tee "$log"
if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load" "$log"; then
  echo "check_project: errors found while running the project" >&2
  exit 1
fi
echo "check_project: game booted and ran 300 frames without errors"
