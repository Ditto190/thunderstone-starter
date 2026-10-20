#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${ROOT}/scripts/thunderstone-workspace.sh"

# shellcheck disable=SC1090
out="$(
  unset THUNDERSTONE_OPERATIONAL_ROOT
  # shellcheck disable=SC1090
  source "$LIB"
  fail=0
  for name in THUNDERSTONE_REPO_ROOT THUNDERSTONE_WORKSPACE_CONFIG \
    THUNDERSTONE_OPERATIONAL_ROOT THUNDERSTONE_START_DIR THUNDERSTONE_BRIDGE_DIR; do
    if ! declare -p "$name" 2>/dev/null | grep -q ' -x '; then
      echo "not exported: $name" >&2
      fail=1
    fi
  done
  for fn in croot cworkspace cbridge dc-bridge-health dc-bridge-test; do
    if [[ "$(type -t "$fn")" != function ]]; then
      echo "missing function: $fn" >&2
      fail=1
    fi
  done
  [[ -d "$THUNDERSTONE_REPO_ROOT" ]] || { echo "repo root not a directory" >&2; fail=1; }
  [[ "$THUNDERSTONE_REPO_ROOT" == "$ROOT" ]] || {
    echo "repo root mismatch: $THUNDERSTONE_REPO_ROOT" >&2
    fail=1
  }
  [[ "$THUNDERSTONE_WORKSPACE_CONFIG" == "$THUNDERSTONE_REPO_ROOT/config/agent-workspace.json" ]] || {
    echo "config path mismatch" >&2
    fail=1
  }
  [[ -f "$THUNDERSTONE_WORKSPACE_CONFIG" ]] || { echo "config file missing" >&2; fail=1; }
  [[ -d "$THUNDERSTONE_OPERATIONAL_ROOT" ]] || { echo "ops root not a directory" >&2; fail=1; }
  [[ "$THUNDERSTONE_START_DIR" == "$THUNDERSTONE_OPERATIONAL_ROOT" ]] || {
    echo "start dir mismatch" >&2
    fail=1
  }
  [[ "$THUNDERSTONE_BRIDGE_DIR" == "$THUNDERSTONE_OPERATIONAL_ROOT/bridge" ]] || {
    echo "bridge dir mismatch" >&2
    fail=1
  }
  exit "$fail"
)" || {
  echo "thunderstone-workspace test FAIL" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

echo "thunderstone-workspace tests passed."
