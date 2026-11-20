#!/usr/bin/env bash
# run-task.sh usage-limit guard: only a status field starting with "usage-limit"
# on today's row blocks; free-text mentions do not.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home" "$TMP/ops/state"
printf '#!/bin/sh\nexit 42\n' >"$TMP/bin/agent"
chmod +x "$TMP/bin/agent"
printf 'brief\n' >"$TMP/brief.md"
TODAY="$(TZ=Australia/Sydney date +%F)"
L="$TMP/ops/state/cloud-agent-ledger.md"
run() {
  set +e
  env -u BASH_ENV -u ENV HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" \
    THUNDERSTONE_OPERATIONAL_ROOT="$TMP/ops" bash "$ROOT/scripts/run-task.sh" "$TMP/brief.md" >/dev/null 2>&1
  code=$?
  set -e
}
expect() { run; [ "$code" -eq "$1" ] || { echo "guard test FAIL ($2): expected $1, got $code" >&2; exit 1; }; }
printf '| %s | fix | runner | repo | done, usage-limit test hardened |\n' "$TODAY" >"$L"
expect 42 "free-text mention"
printf '| %s | brief | runner | repo | done |\n| %s | brief | runner | repo | usage-limit, exit 75 |\n' "$TODAY" "$TODAY" >"$L"
expect 75 "status usage-limit"
printf '| 2000-01-01 | brief | runner | repo | usage-limit |\n' >"$L"
expect 42 "old usage-limit row"
printf '| %s | brief | runner | repo | usage-limit | |\n' "$TODAY" >"$L"
expect 75 "usage-limit before trailing blank fields"
printf '| %s | brief | runner | repo | | |\n' "$TODAY" >"$L"
expect 42 "blank status fields"
printf '\n|\n| %s |\n' "$TODAY" >"$L"
expect 42 "blank and short rows"
echo "run-task guard tests passed."
