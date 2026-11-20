#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$ROOT/scripts/ts-session.sh"
TMP="$(mktemp -d)"
S=""
cleanup() {
  if [[ -n "$S" ]]; then
    bash "$TS" stop "$S" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
export TS_STATE="$TMP/state" TS_LEDGER="$TMP/ledger.tsv" TS_SOCKET="${TS_SOCKET:-ts-shared}"
mkdir -p "$TS_STATE"

fail_name() {
  local name="$1" rc
  set +e
  bash "$TS" start "$name" --cmd 'true' >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" == 2 ]] || { echo "expected rc=2 for name=$name got $rc"; exit 1; }
}

fail_name 'bad.name'
fail_name 'dc'
fail_name 'thunderstone'

S="tsunit-echo-$$"
bash "$TS" start "$S" --cmd 'bash --norc --noprofile -i' >/dev/null
tmux -L "$TS_SOCKET" has-session -t "=$S"

set +e
bash "$TS" read dc 5 >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" == 2 ]] || { echo "read dc should refuse rc=2 got $rc"; exit 1; }

bash "$TS" send "$S" 'printf DONE-BOUNDARY-1\n'
sleep 0.5
bash "$TS" send "$S" 'printf DONE-BOUNDARY-2\n'
if ! bash "$TS" wait "$S" 'DONE-BOUNDARY-2' 8; then
  echo "wait should match second send output only"
  exit 1
fi
if bash "$TS" wait "$S" 'DONE-BOUNDARY-1' 2; then
  echo "wait should not match stale DONE from first send"
  exit 1
fi

echo "ts-session-test passed"
