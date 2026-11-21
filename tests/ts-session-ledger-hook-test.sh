#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LEDGER="$TMP/ledger.tsv"
export TS_HOOK_LEDGER="$LEDGER"

run_hook() {
  printf '%s' "$1" | bash "$ROOT/scripts/ts-session-ledger-hook.sh"
}

run_hook '{"session_id":"sess-abc-123"}'
line="$(tail -n 1 "$LEDGER")"
IFS=$'\t' read -r _ts _actor verb _name chat _detail <<<"$line"
[[ "$verb" == sessionStart ]] || { echo "verb not sessionStart: $verb"; exit 1; }
[[ "$chat" == sess-abc-123 ]] || { echo "chat id mismatch: $chat"; exit 1; }
[[ "$_actor" == "${USER:-unknown}" ]] || { echo "actor mismatch: $_actor"; exit 1; }
nf="$(awk -F'\t' '{print NF}' <<<"$line")"
[[ "$nf" == 6 ]] || { echo "expected 6 columns, got $nf"; exit 1; }

run_hook $'{\n  "params": {"sessionId": "nested-99"}\n}'
line="$(tail -n 1 "$LEDGER")"
IFS=$'\t' read -r _ _ _ _ chat _ <<<"$line"
[[ "$chat" == nested-99 ]] || { echo "multiline parse failed: $chat"; exit 1; }

test -f "$LEDGER.lock"
echo "ts-session-ledger-hook-test passed"