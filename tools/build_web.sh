#!/usr/bin/env bash
# Builds the browser version into build/web (index.html + files). It runs on
# any phone or computer browser, and can be added to the iPhone Home Screen.
# Needs the Godot web export templates: downloaded once into Godot's template
# folder if missing (about 1.3 GB download, 20 MB kept).
# Optional: set SUPABASE_URL and SUPABASE_ANON_KEY to include online features.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"
if [[ ! -f "$templates/web_nothreads_release.zip" ]]; then
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  echo "Downloading export templates from $url"
  curl -sSLf -o "$work/templates.tpz" "$url"
  unzip -oq "$work/templates.tpz" 'templates/web_nothreads_*' templates/version.txt -d "$work"
  mkdir -p "$templates"
  cp "$work"/templates/* "$templates/"
fi

if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
  ./tools/write_backend_config.sh
fi

rm -rf build/web
mkdir -p build/web
# Godot must not import or pack its own build output.
touch build/.gdignore
"$GODOT" --headless --import < /dev/null > /dev/null 2>&1
"$GODOT" --headless --export-release "Web" build/web/index.html < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^ERROR|SCRIPT ERROR|Parse Error" && exit 1
for file in index.html index.js index.wasm index.pck index.manifest.json; do
  [[ -s "build/web/$file" ]] || { echo "build_web: build/web/$file is missing" >&2; exit 1; }
done
touch build/web/.nojekyll
echo "build_web: built build/web ($(du -sh build/web | cut -f1))"
