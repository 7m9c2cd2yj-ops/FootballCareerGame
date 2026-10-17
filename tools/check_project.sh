#!/usr/bin/env bash
# 1) Compiles every one of our scripts with --check-only, so warnings that the
#    project treats as errors (e.g. untyped declarations) fail even in scripts
#    no test loads yet.
# 2) Boots the game headless for a few hundred frames and fails on any script
#    or engine error in the output (Godot exits 0 on most runtime errors).
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

"$GODOT" --headless --import

failed=0
while IFS= read -r script; do
  if ! "$GODOT" --headless --check-only -s "res://$script" >/dev/null 2>&1; then
    echo "check_project: compile error in $script" >&2
    "$GODOT" --headless --check-only -s "res://$script" 2>&1 | grep -E "ERROR" >&2 || true
    failed=1
  fi
done < <(find "${GD_SOURCE_DIRS[@]}" -name "*.gd" | sort)
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
echo "check_project: all scripts compile"

log="$(mktemp)"
"$GODOT" --headless --quit-after 300 2>&1 | tee "$log"
if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load" "$log"; then
  echo "check_project: errors found while running the project" >&2
  exit 1
fi
echo "check_project: game booted and ran 300 frames without errors"
