#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home/.local/bin" "$TMP/scripts" "$TMP/elsewhere"
cp "$ROOT/scripts/run-task.sh" "$ROOT/scripts/env-run.mjs" "$ROOT/scripts/clan.mjs" "$ROOT/scripts/clan-contract.mjs" "$TMP/scripts/"
cat >"$TMP/home/.local/bin/node" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${NODE_LOG:?}"
exit 0
EOF
chmod +x "$TMP/home/.local/bin/node"
export NODE_LOG="$TMP/node.log"
export HOME="$TMP/home"
export PATH="/usr/bin:/bin"
touch "$NODE_LOG"
(
  cd "$TMP/elsewhere"
  bash "$TMP/scripts/run-task.sh" TASK-010
)
test -f "$TMP/.state/run.lock" || { echo "run-task-test FAIL: lock missing" >&2; exit 1; }
grep -q 'env-run.mjs node' "$NODE_LOG" || { echo "run-task-test FAIL: env-run not invoked" >&2; exit 1; }
grep -q 'clan.mjs run TASK-010' "$NODE_LOG" || { echo "run-task-test FAIL: args not forwarded" >&2; exit 1; }
bash -c 'exec 9>"$1/.state/run.lock"; flock -n 9; sleep 30' bash "$TMP" &
holder=$!
trap 'kill "$holder" 2>/dev/null || true; rm -rf "$TMP"' EXIT
sleep 0.2
if bash "$TMP/scripts/run-task.sh" TASK-010 >/dev/null 2>"$TMP/err"; then
  echo "run-task-test FAIL: second run ignored the lock" >&2
  exit 1
fi
grep -q 'Another run holds this checkout' "$TMP/err" || { echo "run-task-test FAIL: lock message missing" >&2; exit 1; }
echo "run-task-test passed"
