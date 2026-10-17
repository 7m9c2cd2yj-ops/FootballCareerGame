#!/usr/bin/env bash
# Prints overall-rating curves for whole careers using data/balance.json.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless -s tools/balance_report.gd 2>&1 | grep -v "^Godot Engine"
