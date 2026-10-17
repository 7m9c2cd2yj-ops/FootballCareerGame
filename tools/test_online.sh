#!/usr/bin/env bash
# Runs the game's online client end to end against the local mock backend
# (tools/mock_supabase.py): sync up/down, ranking, ARENA, preset names,
# forged-career rejection, account deletion, offline behaviour.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_ROOT"

PORT="${MOCK_PORT:-54400}"
if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
  echo "test_online: port $PORT is already in use (a leftover mock?); set MOCK_PORT" >&2
  exit 1
fi
CONFIG="$(mktemp --suffix=.json)"
echo "{\"url\": \"http://127.0.0.1:$PORT\", \"anon_key\": \"dev-anon-key\"}" > "$CONFIG"
python3 tools/mock_supabase.py --port "$PORT" --anon-key dev-anon-key &
MOCK_PID=$!
trap 'kill $MOCK_PID 2>/dev/null; rm -f "$CONFIG"' EXIT
# Wait until the mock accepts connections; a slow start would otherwise make
# the first syncs look "offline" and fail checks for the wrong reason.
for _ in $(seq 1 50); do
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "test_online: the mock backend exited during startup" >&2
    exit 1
  fi
  if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
    break
  fi
  sleep 0.2
done

"$GODOT" --headless --import < /dev/null > /dev/null 2>&1
KL_BACKEND_CONFIG="$CONFIG" KL_ONLINE_STATE_DIR="user://online_smoke_state" "$GODOT" --headless -s tools/online_smoke.gd < /dev/null 2>&1 \
  | grep -vE "^Godot Engine|^$"
