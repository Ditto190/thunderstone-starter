#!/usr/bin/env bash
# Report browser stack readiness; non-zero if core path missing.
set -uo pipefail
PORT="${BROWSER_CDP_PORT:-9222}"
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then echo "BROWSER_CDP_PORT must be numeric" >&2; exit 2; fi
fail=0
# chk <label> <core|opt> <command...>  (runs the command directly, no eval)
chk() {
  local label="$1" level="$2"; shift 2
  if "$@" >/dev/null 2>&1; then echo "ok   $label"; else echo "miss $label"; [ "$level" = core ] && fail=1; fi
}
chk docker core command -v docker
chk cdp core curl -fsS "http://127.0.0.1:${PORT}/json/version"
chk agent-browser core command -v agent-browser
chk scrapling opt command -v scrapling
chk "npx (firecrawl-mcp prerequisite)" opt command -v npx
chk rustwright-mcp opt command -v rustwright-mcp
exit "$fail"
