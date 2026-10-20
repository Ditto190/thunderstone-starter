#!/usr/bin/env bash
# Behaviour checks for connector setup. No network, Docker, or package installs.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
root="$PWD"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Profile stays dev unless THUNDERSTONE_PROFILE=vm, even on Xfce.
out="$(env -u THUNDERSTONE_PROFILE XDG_CURRENT_DESKTOP=XFCE node scripts/mcp-sync.mjs --print-profile)"
[ "$out" = "dev" ]
out="$(env THUNDERSTONE_PROFILE=vm XDG_CURRENT_DESKTOP=XFCE node scripts/mcp-sync.mjs --print-profile)"
[ "$out" = "vm" ]

# Prune cannot escape the skill directory. Skip removes only marked skills.
# shellcheck disable=SC1091
SKILLS_INSTALL_SOURCE_ONLY=1 source "$root/scripts/skills-install.sh"
skill="$work/skill"
mkdir -p "$skill/assets" "$work/outside"
echo keep > "$work/outside/note"
if safe_prune "../outside" "$skill"; then echo "prune escape was accepted" >&2; exit 1; fi
test -f "$work/outside/note"
safe_prune "assets" "$skill"
test ! -e "$skill/assets"

DEST="$work/dest"
MODE=install
mkdir -p "$DEST/alpha" "$DEST/mine"
printf '%s %s %s\n' anthropic example deadbeef > "$DEST/alpha/.thunderstone-managed"
echo mine > "$DEST/mine/SKILL.md"
remove_skipped anthropic
test ! -e "$DEST/alpha"
test -f "$DEST/mine/SKILL.md"

# Desktop installer: write vm once; keep an explicit project profile.
home1="$work/home1"
mkdir -p "$home1"
HOME="$home1" THUNDERSTONE_ENV_LOCAL="$work/empty.env" bash scripts/install-desktop.sh >/dev/null
grep -qx 'THUNDERSTONE_PROFILE=vm' "$home1/.config/thunderstone/env"
printf '%s\n' 'THUNDERSTONE_PROFILE=dev' > "$work/project.env"
home2="$work/home2"
mkdir -p "$home2"
HOME="$home2" THUNDERSTONE_ENV_LOCAL="$work/project.env" bash scripts/install-desktop.sh >/dev/null
test ! -e "$home2/.config/thunderstone/env" || ! grep -q '^THUNDERSTONE_PROFILE=' "$home2/.config/thunderstone/env"

# agent-setup modes without installs. Missing agent-browser fails --doctor.
bindir="$work/bin"
mkdir -p "$bindir"
cat > "$bindir/tmux" <<'EOF'
#!/bin/sh
case "$1" in
  has-session) exit 1 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$bindir/tmux"
node_bin="$work/nodebin"
mkdir -p "$node_bin"
ln -s "$(command -v node)" "$node_bin/node"
dry_path="$bindir:$node_bin:/usr/bin:/bin"
out_dir="$work/out"
env -u THUNDERSTONE_PROFILE HOME="$work/home-agent" PATH="$dry_path" AGENT_SETUP_DRY=1 AGENT_SETUP_OUT="$out_dir" \
  bash scripts/agent-setup.sh --install >/dev/null
test -f "$out_dir/.grok/config.toml"
env -u THUNDERSTONE_PROFILE HOME="$work/home-agent" PATH="$dry_path" AGENT_SETUP_DRY=1 AGENT_SETUP_OUT="$out_dir" \
  bash scripts/agent-setup.sh --start >/dev/null
env -u THUNDERSTONE_PROFILE HOME="$work/home-agent" PATH="$dry_path" AGENT_SETUP_DRY=1 AGENT_SETUP_OUT="$work/sync-out" \
  bash scripts/agent-setup.sh --sync >/dev/null
if env -u THUNDERSTONE_PROFILE HOME="$work/home-agent" PATH="$dry_path" bash scripts/agent-setup.sh --doctor >/dev/null; then
  echo "doctor succeeded without agent-browser" >&2
  exit 1
fi

# resume.sh still finishes when setup is best-effort.
env -u THUNDERSTONE_PROFILE HOME="$work/home-resume" PATH="$dry_path" AGENT_SETUP_DRY=1 AGENT_SETUP_OUT="$work/resume-out" \
  bash scripts/resume.sh | grep -q 'Ready: tmux attach -t thunderstone'

echo "agent connector tests passed"
