#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
failed=0
for tool in bash tmux git curl unzip zip jq rg fzf python3 node npm rclone shellcheck make cc; do
  if command -v "$tool" >/dev/null; then printf 'OK %s\n' "$tool"
  else printf 'MISSING %s\n' "$tool"; failed=1; fi
done
for tool in agent grok xfce4-terminal systemctl docker; do
  if command -v "$tool" >/dev/null; then printf 'AVAILABLE %s\n' "$tool"; else printf 'OPTIONAL/MANUAL %s\n' "$tool"; fi
done
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  echo "User systemd reachable; not required by starter."
else echo "No reachable user systemd; tmux + XDG autostart are used."; fi
exit "$failed"
