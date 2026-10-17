#!/usr/bin/env bash
# Writes config/backend.local.json (git-ignored) from SUPABASE_URL and
# SUPABASE_ANON_KEY (environment or .env). Run before exporting a build that
# should have online features. Never put the service-role key here.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
: "${SUPABASE_URL:?set SUPABASE_URL (see .env.example)}"
: "${SUPABASE_ANON_KEY:?set SUPABASE_ANON_KEY (see .env.example)}"
mkdir -p config
python3 -c 'import json,os,sys; json.dump({"url": os.environ["SUPABASE_URL"], "anon_key": os.environ["SUPABASE_ANON_KEY"]}, sys.stdout)' > config/backend.local.json
echo "Wrote config/backend.local.json for $SUPABASE_URL"
