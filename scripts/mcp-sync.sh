#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

HTTP_EXAMPLE="config/mcp/http-remote.example.json"
BROWSER_EXAMPLE="config/browser/mcp.example.json"
OUT=".cursor/mcp.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for mcp-sync.sh" >&2
  exit 1
fi

for f in "$HTTP_EXAMPLE" "$BROWSER_EXAMPLE"; do
  if [[ ! -f "$f" ]]; then
    echo "missing $f" >&2
    exit 1
  fi
done

mkdir -p .cursor

# HTTP remotes win on name clashes (e.g. firecrawl).
jq -s '
  .[0].mcpServers * .[1].mcpServers | { mcpServers: . }
' "$BROWSER_EXAMPLE" "$HTTP_EXAMPLE" >"$OUT"

echo "Wrote $OUT ($(jq -r '.mcpServers | keys | join(", ")' "$OUT"))"
