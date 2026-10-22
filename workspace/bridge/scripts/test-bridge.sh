#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${PORT:-3999}"
if [[ "$PORT" == "3847" ]]; then
  echo "FAIL: refusing to bind or probe port 3847." >&2
  exit 2
fi
export BRIDGE_PORT="$PORT"
if [[ "$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "http://127.0.0.1:${PORT}/health" || true)" != "000" ]]; then
  echo "FAIL: port ${PORT} already has a responding service; refusing to test against or stop it." >&2
  exit 2
fi
LOG_FILE="$(mktemp)"
SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    for _ in {1..20}; do kill -0 "$SERVER_PID" 2>/dev/null || break; sleep 0.1; done
    kill -9 "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT INT TERM
# Launch the actual Node/tsx process directly so cleanup cannot orphan an npm child.
BRIDGE_PORT="$PORT" ./node_modules/.bin/tsx src/server.ts >"$LOG_FILE" 2>&1 &
SERVER_PID=$!
READY=0
for _ in {1..40}; do
  if [[ "$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "http://127.0.0.1:${PORT}/health" || true)" == "401" ]]; then READY=1; break; fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then break; fi
  sleep 0.25
done
if [[ "$READY" != 1 ]]; then
  echo "FAIL: bridge did not become healthy. Sanitized startup diagnostics:" >&2
  grep -E 'Error|error|listening|Cannot find|MODULE_NOT_FOUND|ERR_|not found' "$LOG_FILE" | tail -20 >&2 || true
  exit 1
fi
BRIDGE_PORT="$PORT" node --test scripts/test-bridge.test.mjs scripts/test-chatgpt-stdio-adapter.test.mjs
