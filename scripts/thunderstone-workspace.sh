# shellcheck shell=bash
# Thunderstone workspace defaults (portable config lives in config/agent-workspace.json).
# Sourced by interactive Bash on the Grok Bot VM; intentionally does not auto-cd.
# Resolve through the real scripts dir so a thunderstone/scripts symlink does not
# make ".." point at the ops tree.
_ts_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || _ts_script_dir=""
if [[ -n "$_ts_script_dir" ]]; then
  THUNDERSTONE_REPO_ROOT="$(cd "$_ts_script_dir/.." && pwd)" || THUNDERSTONE_REPO_ROOT=""
else
  THUNDERSTONE_REPO_ROOT=""
fi
unset _ts_script_dir
THUNDERSTONE_WORKSPACE_CONFIG="$THUNDERSTONE_REPO_ROOT/config/agent-workspace.json"
if [[ -z "${THUNDERSTONE_OPERATIONAL_ROOT:-}" ]]; then
  if [[ -n "$THUNDERSTONE_REPO_ROOT" && -d "$THUNDERSTONE_REPO_ROOT/../thunderstone" ]]; then
    THUNDERSTONE_OPERATIONAL_ROOT="$(cd "$THUNDERSTONE_REPO_ROOT/../thunderstone" && pwd)" || THUNDERSTONE_OPERATIONAL_ROOT=""
  else
    echo "warn: thunderstone operational root not found" >&2
    THUNDERSTONE_OPERATIONAL_ROOT=""
  fi
fi
if [[ -n "$THUNDERSTONE_OPERATIONAL_ROOT" ]]; then
  THUNDERSTONE_START_DIR="$THUNDERSTONE_OPERATIONAL_ROOT"
  THUNDERSTONE_BRIDGE_DIR="$THUNDERSTONE_OPERATIONAL_ROOT/bridge"
else
  THUNDERSTONE_START_DIR=""
  THUNDERSTONE_BRIDGE_DIR=""
fi
export THUNDERSTONE_REPO_ROOT THUNDERSTONE_WORKSPACE_CONFIG
export THUNDERSTONE_OPERATIONAL_ROOT THUNDERSTONE_START_DIR THUNDERSTONE_BRIDGE_DIR

croot() { cd "$THUNDERSTONE_REPO_ROOT" || return; }
cworkspace() {
  if [[ -z "${THUNDERSTONE_START_DIR:-}" ]]; then
    echo "cworkspace: THUNDERSTONE_START_DIR is empty" >&2
    return 1
  fi
  cd "$THUNDERSTONE_START_DIR" || return
}
cbridge() {
  if [[ -z "${THUNDERSTONE_BRIDGE_DIR:-}" ]]; then
    echo "cbridge: THUNDERSTONE_BRIDGE_DIR is empty" >&2
    return 1
  fi
  cd "$THUNDERSTONE_BRIDGE_DIR" || return
}
dc-bridge-health() { curl --fail --silent --show-error http://127.0.0.1:3847/health; }
dc-bridge-test() {
  if [[ -z "${THUNDERSTONE_BRIDGE_DIR:-}" ]]; then
    echo "dc-bridge-test: THUNDERSTONE_BRIDGE_DIR is empty" >&2
    return 1
  fi
  (cd "$THUNDERSTONE_BRIDGE_DIR" && npm test)
}
