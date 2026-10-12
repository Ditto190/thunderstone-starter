#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v grok >/dev/null 2>&1; then
  cat <<'EOF'
OPTIONAL: Grok CLI not on PATH.
Install Grok Build / Grok CLI from xAI docs, then run:
  bash scripts/grok-mcp-bootstrap.sh
EOF
  exit 0
fi

has_server() {
  grok mcp list 2>/dev/null | rg -q "(^|[[:space:]])${1}([[:space:]]|$)"
}

add_http() {
  local name="$1"
  local url="$2"
  if has_server "$name"; then
    printf 'SKIP grok mcp %s (already listed)\n' "$name"
    return 0
  fi
  grok mcp add --transport http "$name" "$url"
}

add_http xai-docs "https://docs.x.ai/api/mcp"
add_http context7 "https://mcp.context7.com/mcp/oauth"
add_http github "https://api.githubcopilot.com/mcp/"
add_http firecrawl "https://mcp.firecrawl.dev/v2/mcp-oauth"

printf 'Running grok mcp doctor xai-docs...\n'
grok mcp doctor xai-docs || true

printf 'Done. Complete OAuth in the browser when prompted for context7, github, and firecrawl.\n'
printf 'Project catalog reference: %s\n' "$ROOT/config/grok/mcp.catalog.toml.example"
