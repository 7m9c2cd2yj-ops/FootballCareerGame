#!/usr/bin/env bash
# Exports the game data pack (no export templates or SDKs needed) for each
# preset in export_presets.cfg and checks what went in: every data/*.json
# file, our scripts and scenes, and none of tests/, tools/, addons/gut/,
# backend/ or docs/. Full AAB/IPA builds need templates and signing; see
# docs/RELEASE.md.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

out_dir="$(mktemp -d)"
trap 'rm -rf "$out_dir"' EXIT
"$GODOT" --headless --import < /dev/null > /dev/null 2>&1

for preset in Android iOS; do
  log="$out_dir/$preset.log"
  "$GODOT" --headless --export-pack "$preset" "$out_dir/$preset.pck" < /dev/null > "$log" 2>&1
  stored="$(grep -o 'Storing File: res://[^ ]*' "$log" | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^Storing File: res:\/\///')"
  for data_file in data/*.json; do
    if ! grep -qx "$data_file" <<< "$stored"; then
      echo "check_export: $preset pack is missing $data_file" >&2
      exit 1
    fi
  done
  for required in scripts/app/session.gdc scenes/main/main_menu.tscn project.binary; do
    if ! grep -q "^$required" <<< "$stored"; then
      echo "check_export: $preset pack is missing $required" >&2
      exit 1
    fi
  done
  if grep -qE '^(tests|tools|addons/gut|backend|docs)/' <<< "$stored"; then
    echo "check_export: $preset pack contains files that must stay out:" >&2
    grep -E '^(tests|tools|addons/gut|backend|docs)/' <<< "$stored" >&2
    exit 1
  fi
  echo "check_export: $preset pack has $(wc -l <<< "$stored") files, data included, dev files excluded"
done
