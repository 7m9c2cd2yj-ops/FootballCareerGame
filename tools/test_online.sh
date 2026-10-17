#!/usr/bin/env bash
# Runs the game's online client end to end against the local mock backend
# (tools/mock_supabase.py): sync up/down, ranking, ARENA, preset names,
# forged-career rejection, account deletion, offline behaviour.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

PORT="${MOCK_PORT:-54400}"
CONFIG="$(mktemp --suffix=.json)"
echo "{\"url\": \"http://127.0.0.1:$PORT\", \"anon_key\": \"dev-anon-key\"}" > "$CONFIG"
python3 tools/mock_supabase.py --port "$PORT" --anon-key dev-anon-key &
MOCK_PID=$!
trap 'kill $MOCK_PID 2>/dev/null; rm -f "$CONFIG"' EXIT
sleep 1

"$GODOT" --headless --import < /dev/null > /dev/null 2>&1
KL_BACKEND_CONFIG="$CONFIG" KL_ONLINE_STATE_DIR="user://online_smoke_state" "$GODOT" --headless -s tools/online_smoke.gd < /dev/null 2>&1 \
  | grep -vE "^Godot Engine|^$"
