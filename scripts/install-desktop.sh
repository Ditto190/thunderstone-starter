#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Desktop Exec paths are double quoted; reject characters requiring extra escaping.
[[ "$ROOT" =~ ^[a-zA-Z0-9_./\ -]+$ ]] || { echo "Move starter to a simple path."; exit 1; }
mkdir -p "$HOME/.config/autostart" "$HOME/.local/share/applications"
write_entry() {
  local dest="$1" terminal="$2" script="$3" tmp
  tmp="$(mktemp)"
  printf '[Desktop Entry]\nType=Application\nName=Thunderstone Terminal\nExec=/usr/bin/env bash "%s/scripts/%s"\nTerminal=%s\n' "$ROOT" "$script" "$terminal" > "$tmp"
  if [[ -f "$dest" ]] && ! cmp -s "$tmp" "$dest"; then
    rm "$tmp"; echo "Refusing to overwrite $dest"; exit 1
  fi
  install -m 644 "$tmp" "$dest"; rm "$tmp"
}
write_entry "$HOME/.config/autostart/thunderstone.desktop" false resume.sh
write_entry "$HOME/.local/share/applications/thunderstone.desktop" true terminal.sh
# This desktop installer only runs on the Grok Bot VM, so record that profile once (never overwrite a choice).
env_file="$HOME/.config/thunderstone/env"
mkdir -p "$(dirname "$env_file")"
if ! grep -qs '^THUNDERSTONE_PROFILE=' "$env_file"; then
  (umask 077; printf 'THUNDERSTONE_PROFILE=vm\n' >> "$env_file")
fi
echo "Installed application launcher and desktop-login autostart."
