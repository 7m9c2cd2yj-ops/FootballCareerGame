#!/usr/bin/env bash
# Lints and format-checks our GDScript. Pass --fix to reformat in place.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

if [[ "${1:-}" == "--fix" ]]; then
  gdformat "${GD_SOURCE_DIRS[@]}"
else
  gdformat --check "${GD_SOURCE_DIRS[@]}"
fi
gdlint "${GD_SOURCE_DIRS[@]}"
