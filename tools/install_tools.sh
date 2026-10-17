#!/usr/bin/env bash
# Installs the pinned Godot (Linux x86_64, headless-capable) into .tools/
# and gdtoolkit (gdlint/gdformat) via pip. Used locally and in CI.
set -euo pipefail
source "$(dirname "$0")/env.sh"

mkdir -p "$PROJECT_ROOT/.tools"
if [[ ! -x "$PROJECT_ROOT/.tools/godot" ]]; then
  archive="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${archive}.zip"
  echo "Downloading $url"
  curl -sSLf -o "$PROJECT_ROOT/.tools/godot.zip" "$url"
  unzip -o -q "$PROJECT_ROOT/.tools/godot.zip" -d "$PROJECT_ROOT/.tools"
  mv "$PROJECT_ROOT/.tools/$archive" "$PROJECT_ROOT/.tools/godot"
  rm "$PROJECT_ROOT/.tools/godot.zip"
fi
"$PROJECT_ROOT/.tools/godot" --version

python3 -m pip install --quiet "gdtoolkit==${GDTOOLKIT_VERSION}"
gdlint --version
