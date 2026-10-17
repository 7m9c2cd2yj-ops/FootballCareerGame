#!/usr/bin/env bash
# Shared settings for tools/*.sh. Source it, don't run it.
# Resolves the Godot binary: $GODOT_BIN, then .tools/godot, then `godot` on PATH.

GODOT_VERSION="4.7.2"
GDTOOLKIT_VERSION="4.5.0"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif [[ -x "$PROJECT_ROOT/.tools/godot" ]]; then
  GODOT="$PROJECT_ROOT/.tools/godot"
else
  GODOT="godot"
fi

# Folders containing our own GDScript (addons/ is vendored and not linted).
GD_SOURCE_DIRS=(scripts tests tools)
