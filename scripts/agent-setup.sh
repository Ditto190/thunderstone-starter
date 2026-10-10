#!/usr/bin/env bash
# One idempotent entry point that makes the browser stack, MCP connectors and skills ready for
# Grok Build, Grok Bot and Cursor. Does not touch Perplexity Computer or Comet (see docs/agent-connectors).
# Never starts a paid agent task. Every step is best effort: a failure prints a warning and setup continues.
#
#   --install  bootstrap time: install tools, pull CloakBrowser, install skills, sync MCP configs
#   --start    login time: start CloakBrowser if Docker is available, sync MCP configs
#   --sync     regenerate .grok/config.toml and .cursor/mcp.json only
#   --doctor   report readiness; exits non-zero only when the core browser path is missing
set -uo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1
export PATH="$HOME/.local/bin:$PATH"
MODE="${1:---start}"
case "$MODE" in --install|--start|--sync|--doctor) ;; *) echo "Usage: $0 [--install|--start|--sync|--doctor]" >&2; exit 2;; esac

AGENT_BROWSER_VERSION="${AGENT_BROWSER_VERSION:-0.39.0}"
warn() { echo "agent-setup: $*" >&2; }
step() { echo "agent-setup: $*"; }
run() { "$@" || warn "step failed (continuing): $*"; }
profile() { node scripts/env-run.mjs node scripts/mcp-sync.mjs --print-profile 2>/dev/null || echo dev; }
docker_ok() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

sync_mcp() { step "syncing MCP configs"; run node scripts/env-run.mjs node scripts/mcp-sync.mjs; }

install_agent_browser() {
  command -v agent-browser >/dev/null 2>&1 && return 0
  step "installing agent-browser@$AGENT_BROWSER_VERSION into ~/.local"
  run npm install -g --prefix "$HOME/.local" --no-audit --no-fund "agent-browser@$AGENT_BROWSER_VERSION"
  # npm declares node >= 24 for this package, but the CLI is a native binary; confirm it actually starts here.
  agent-browser --version >/dev/null 2>&1 || warn "agent-browser installed but does not start on Node $(node -v 2>/dev/null); upgrade Node or set AGENT_BROWSER_VERSION"
}

# Cua Driver is for the Grok Bot VM profile only. The installer is saved and run from .state, like the Cursor installer.
install_cua() {
  [ "${SKIP_CUA_INSTALL:-0}" = 1 ] && return 0
  command -v cua-driver >/dev/null 2>&1 && return 0
  if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
    warn "Cua Driver needs x86_64 Linux; skipping"
    return 0
  fi
  step "installing Cua Driver (VM profile)"
  local installer
  installer="$(mktemp)"
  # A fresh temp file each time, so a failed download can never run an older installer.
  if curl --proto '=https' --tlsv1.2 -fsS https://cua.ai/driver/install.sh -o "$installer" && [ -s "$installer" ]; then
    run bash "$installer"
  else
    warn "Cua Driver download failed; skipping"
  fi
  rm -f "$installer"
}

start_browser() {
  if docker_ok; then
    step "starting CloakBrowser sidecar"
    run bash scripts/browser-up.sh
  else
    warn "Docker not reachable: CloakBrowser (browser tier 4) unavailable; Firecrawl and Scrapling tiers still work"
  fi
}

doctor() {
  local fail=0 p
  p="$(profile)"
  echo "profile: $p"
  check() { # label core|opt command...
    local label="$1" level="$2"; shift 2
    if "$@" >/dev/null 2>&1; then echo "ok   $label"; else echo "miss $label"; [ "$level" = core ] && fail=1; fi
  }
  check "agent-browser" core command -v agent-browser
  check "docker daemon" opt docker info
  check "CloakBrowser CDP :${BROWSER_CDP_PORT:-9222}" opt curl -fsS "http://127.0.0.1:${BROWSER_CDP_PORT:-9222}/json/version"
  check ".grok/config.toml" opt test -f .grok/config.toml
  check ".cursor/mcp.json" opt test -f .cursor/mcp.json
  check "skills in .agents/skills" opt test -d .agents/skills
  check "grok CLI" opt command -v grok
  if [ "$p" = vm ]; then
    check "cua-driver" opt command -v cua-driver
    check "X display" opt test -n "${DISPLAY:-}"
  fi
  node scripts/env-run.mjs node scripts/mcp-sync.mjs --check 2>&1 | sed 's/^/mcp  /'
  return "$fail"
}

case "$MODE" in
  --install)
    install_agent_browser
    if docker_ok; then run docker pull "${CLOAK_IMAGE:-cloakhq/cloakbrowser}"; fi
    run bash scripts/skills-install.sh
    [ "$(profile)" = vm ] && install_cua
    sync_mcp
    ;;
  --start)
    start_browser
    sync_mcp
    ;;
  --sync) sync_mcp ;;
  --doctor) doctor; exit $? ;;
esac
exit 0
