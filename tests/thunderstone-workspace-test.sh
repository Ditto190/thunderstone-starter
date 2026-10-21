#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
LIB="${ROOT}/scripts/thunderstone-workspace.sh"

# Hermetic: never rely on a real ops tree next to the checkout (CI has none).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# check_env <expected repo root> <expected ops root>; runs in the sourcing subshell.
check_env() {
  local want_repo="$1" want_ops="$2" fail=0 name fn
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
  [[ "$THUNDERSTONE_REPO_ROOT" == "$want_repo" ]] || {
    echo "repo root mismatch: $THUNDERSTONE_REPO_ROOT" >&2
    fail=1
  }
  [[ "$THUNDERSTONE_WORKSPACE_CONFIG" == "$THUNDERSTONE_REPO_ROOT/config/agent-workspace.json" ]] || {
    echo "config path mismatch" >&2
    fail=1
  }
  [[ -f "$THUNDERSTONE_WORKSPACE_CONFIG" ]] || { echo "config file missing" >&2; fail=1; }
  [[ -d "$THUNDERSTONE_OPERATIONAL_ROOT" ]] || { echo "ops root not a directory" >&2; fail=1; }
  [[ "$THUNDERSTONE_OPERATIONAL_ROOT" == "$want_ops" ]] || {
    echo "ops root mismatch: $THUNDERSTONE_OPERATIONAL_ROOT" >&2
    fail=1
  }
  [[ "$THUNDERSTONE_START_DIR" == "$THUNDERSTONE_OPERATIONAL_ROOT" ]] || {
    echo "start dir mismatch" >&2
    fail=1
  }
  [[ "$THUNDERSTONE_BRIDGE_DIR" == "$THUNDERSTONE_OPERATIONAL_ROOT/bridge" ]] || {
    echo "bridge dir mismatch" >&2
    fail=1
  }
  return "$fail"
}

# source_and_check <lib> <expected repo root> <expected ops root>; call inside $(..).
source_and_check() {
  # shellcheck disable=SC1090
  source "$1"
  check_env "$2" "$3"
}

report_fail() {
  echo "thunderstone-workspace test FAIL ($1)" >&2
  printf '%s\n' "$2" >&2
  exit 1
}

# Case 1: real lib, ops root supplied via THUNDERSTONE_OPERATIONAL_ROOT.
OPS="$(cd "$TMP" && mkdir -p ops/bridge && cd ops && pwd -P)"
out="$(THUNDERSTONE_OPERATIONAL_ROOT="$OPS" source_and_check "$LIB" "$ROOT" "$OPS" 2>&1)" ||
  report_fail "env override" "$out"

# Case 2: default sibling discovery (<repo>/../thunderstone) in a temp layout.
FAKE_REPO="$TMP/layout/starter"
mkdir -p "$FAKE_REPO/scripts" "$FAKE_REPO/config" "$TMP/layout/thunderstone/bridge"
cp "$LIB" "$FAKE_REPO/scripts/"
cp "$ROOT/config/agent-workspace.json" "$FAKE_REPO/config/"
FAKE_REPO="$(cd "$FAKE_REPO" && pwd -P)"
SIB_OPS="$(cd "$TMP/layout/thunderstone" && pwd -P)"
# Empty THUNDERSTONE_OPERATIONAL_ROOT takes the lib's discovery branch.
out="$(THUNDERSTONE_OPERATIONAL_ROOT='' source_and_check \
  "$FAKE_REPO/scripts/thunderstone-workspace.sh" "$FAKE_REPO" "$SIB_OPS" 2>&1)" ||
  report_fail "sibling discovery" "$out"

echo "thunderstone-workspace tests passed."
