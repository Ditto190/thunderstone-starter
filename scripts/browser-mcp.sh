#!/usr/bin/env bash
# stdio MCP server: agent-browser driving the CloakBrowser sidecar.
set -euo pipefail
PORT="${BROWSER_CDP_PORT:-9222}"
command -v agent-browser >/dev/null || { echo "install: npm i -g agent-browser" >&2; exit 1; }
exec agent-browser --cdp "http://127.0.0.1:${PORT}" --input-mode human \
  mcp --tools "${BROWSER_MCP_TOOLS:-core,network,state,tabs}"
