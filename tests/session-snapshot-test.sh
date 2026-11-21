#!/usr/bin/env bash
# Hermetic checks for scripts/session-snapshot.sh (show/save/usage).
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP_SCRIPT="$ROOT/scripts/session-snapshot.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO="$TMP/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "test"
printf 'x\n' >"$REPO/f"
git -C "$REPO" add f
git -C "$REPO" commit -qm init

STATE="$TMP/state"
mkdir -p "$STATE" "$TMP/ops/state"

run_snap() {
  SESSION_SNAPSHOT_STATE="$STATE" \
    THUNDERSTONE_REPO="$REPO" \
    MODME_REPO="$TMP/no-modme" \
    THUNDERSTONE_WORKSPACE="$TMP/ops" \
    bash "$SNAP_SCRIPT" "$@"
}

# show with no snapshot yet → message, rc 0
out="$(run_snap show)"
printf '%s\n' "$out" | grep -q 'none yet'

# save then show → header present
run_snap save >/dev/null
out="$(run_snap show)"
printf '%s\n' "$out" | grep -q 'thunderstone session snapshot'
[[ -f "$STATE/session-snapshot.txt" ]]

# bad arg → exit 2
rc=0
run_snap nope >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 2 ]]

# save twice unchanged → show exits 0, footer present, no starter changed
run_snap save >/dev/null
run_snap save >/dev/null
rc=0
out="$(run_snap show)" || rc=$?
[[ "$rc" -eq 0 ]]
printf '%s\n' "$out" | grep -q 'manual: session-snapshot.sh'
printf '%s\n' "$out" | grep -q 'starter changed' && exit 1

# change repo file, save, show → starter changed
printf 'y\n' >"$REPO/f"
run_snap save >/dev/null
out="$(run_snap show)"
printf '%s\n' "$out" | grep -q 'starter changed'

# Must not have written into the real repo .state via this override
[[ ! -f "$ROOT/.state/session-snapshot.txt" ]] || {
  # Only fail if our temp content leaked — skip if a real snapshot already existed.
  if grep -qF "host=" "$ROOT/.state/session-snapshot.txt" 2>/dev/null \
    && cmp -s "$STATE/session-snapshot.txt" "$ROOT/.state/session-snapshot.txt" 2>/dev/null; then
    echo "session-snapshot wrote into real .state" >&2
    exit 1
  fi
}

echo "session-snapshot tests passed."
