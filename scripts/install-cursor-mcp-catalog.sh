#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/config/mcp/thunderstone-mcp.example.json"
TARGET="$ROOT/.cursor/mcp.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (install via bootstrap or your package manager)." >&2
  exit 1
fi

if [[ ! -f "$CATALOG" ]]; then
  echo "Missing catalog: config/mcp/thunderstone-mcp.example.json" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

if [[ -f "$TARGET" ]]; then
  jq -s '
    .[0] as $existing | .[1] as $catalog |
    $existing * {
      mcpServers: (($existing.mcpServers // {}) * ($catalog.mcpServers // {}))
    }
  ' "$TARGET" "$CATALOG" > "${TARGET}.tmp"
  mv "${TARGET}.tmp" "$TARGET"
  echo "Merged Thunderstone MCP catalog into .cursor/mcp.json (existing server keys preserved)."
else
  cp "$CATALOG" "$TARGET"
  echo "Created .cursor/mcp.json from Thunderstone MCP catalog."
fi

echo "Authenticate OAuth servers in Cursor Settings → MCP (or Cloud dashboard → Plugins & MCPs)."
