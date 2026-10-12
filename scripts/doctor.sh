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
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  echo "User systemd reachable; not required by starter."
else echo "No reachable user systemd; tmux + XDG autostart are used."; fi

root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
if command -v lean-ctx >/dev/null; then printf 'OK lean-ctx\n'
else printf 'OPTIONAL/MANUAL lean-ctx\n'; fi
if [ -f "${HOME}/.grok/config.toml" ] && grep -q 'lean-ctx' "${HOME}/.grok/config.toml"; then
  printf 'OK lean-ctx-mcp\n'
else printf 'OPTIONAL/MANUAL lean-ctx-mcp\n'; fi
if [ -f "${HOME}/.grok/trusted_folders.toml" ] && grep -F -q "$root" "${HOME}/.grok/trusted_folders.toml"; then
  printf 'OK grok-trust\n'
else printf 'OPTIONAL/MANUAL grok-trust\n'; fi
if [ -f "$root/.grok/config.toml" ] && grep -q 'mcp_servers.xai-docs' "$root/.grok/config.toml"; then
  printf 'OK xai-docs-project\n'
else printf 'MISSING xai-docs-project\n'; failed=1; fi
if [ -f "$root/.cursor/hooks.json" ] && [ -f "$root/.grok/hooks/thunderstone.json" ] \
  && [ -x "$root/.cursor/hooks/lifecycle.sh" ]; then
  printf 'OK hooks-files\n'
else printf 'MISSING hooks-files\n'; failed=1; fi
exit "$failed"
