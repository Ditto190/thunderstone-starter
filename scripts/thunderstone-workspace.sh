# shellcheck shell=bash
# Thunderstone workspace defaults (portable config lives in config/agent-workspace.json).
# Sourced by interactive Bash on the Grok Bot VM; intentionally does not auto-cd.
THUNDERSTONE_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THUNDERSTONE_WORKSPACE_CONFIG="$THUNDERSTONE_REPO_ROOT/config/agent-workspace.json"
THUNDERSTONE_OPERATIONAL_ROOT="$(cd "$THUNDERSTONE_REPO_ROOT/../thunderstone" && pwd)"
THUNDERSTONE_START_DIR="$THUNDERSTONE_OPERATIONAL_ROOT"
THUNDERSTONE_BRIDGE_DIR="$THUNDERSTONE_OPERATIONAL_ROOT/bridge"
export THUNDERSTONE_REPO_ROOT THUNDERSTONE_WORKSPACE_CONFIG
export THUNDERSTONE_OPERATIONAL_ROOT THUNDERSTONE_START_DIR THUNDERSTONE_BRIDGE_DIR

croot() { cd "$THUNDERSTONE_REPO_ROOT" || return; }
cworkspace() { cd "$THUNDERSTONE_START_DIR" || return; }
cbridge() { cd "$THUNDERSTONE_BRIDGE_DIR" || return; }
dc-bridge-health() { curl --fail --silent --show-error http://127.0.0.1:3847/health; }
dc-bridge-test() { (cd "$THUNDERSTONE_BRIDGE_DIR" && npm test); }
