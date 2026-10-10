#!/usr/bin/env bash
# Report browser stack readiness; non-zero if core path missing.
set -uo pipefail
PORT="${BROWSER_CDP_PORT:-9222}"; fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "miss $1"; [ "$3" = core ] && fail=1; fi; }
chk docker "command -v docker" core
chk cdp "curl -fsS http://127.0.0.1:${PORT}/json/version" core
chk agent-browser "command -v agent-browser" core
chk scrapling "command -v scrapling" opt
chk npx-firecrawl "command -v npx" opt
chk rustwright-mcp "command -v rustwright-mcp" opt
exit "$fail"
