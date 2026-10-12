#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
failed=0
for tool in bash tmux git curl unzip zip jq rg fzf python3 node npm rclone shellcheck make cc; do
  if command -v "$tool" >/dev/null; then printf 'OK %s\n' "$tool"
  else printf 'MISSING %s\n' "$tool"; failed=1; fi
done
for tool in agent grok xfce4-terminal systemctl; do
  if command -v "$tool" >/dev/null; then printf 'AVAILABLE %s\n' "$tool"; else printf 'OPTIONAL/MANUAL %s\n' "$tool"; fi
done
if command -v grok >/dev/null 2>&1; then
  echo "grok MCP servers:"
  grok mcp list 2>/dev/null || echo "  (grok mcp list failed)"
  if ! grok mcp list 2>/dev/null | rg -q '(^|[[:space:]])xai-docs([[:space:]]|$)'; then
    echo "WARN: grok MCP server xai-docs not listed (non-fatal; run scripts/grok-mcp-bootstrap.sh)"
  fi
fi
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  echo "User systemd reachable; not required by starter."
else echo "No reachable user systemd; tmux + XDG autostart are used."; fi
exit "$failed"
