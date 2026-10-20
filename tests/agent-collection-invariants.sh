#!/usr/bin/env bash
# Deterministic coordination invariants for agent collections (pilot gates).
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FIX="${ROOT}/tests/fixtures/handoff"
TMP="$(mktemp -d)"
export HANDOFF_ROOT="${TMP}/handoffs"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

run_id="inv-$(date +%s)-$$"
receipt="${TMP}/r1.json"
jq --arg id "$run_id" '.handoff_id=$id | .receipt_id="inv-1"' "$FIX/receipt-investigator.json" >"$receipt"
bash scripts/handoff-receipt.sh record "$receipt" >/dev/null
out2="$(bash scripts/handoff-receipt.sh record "$receipt")"
grep -q duplicate_ignored <<<"$out2"

if bash scripts/handoff-receipt.sh record <(jq '.handoff_id="../escape"' "$receipt") 2>/dev/null; then
  echo "expected unsafe handoff_id rejection"
  exit 1
fi
test ! -e "${TMP}/escape"

blocked="${TMP}/blocked.json"
jq --arg id "${run_id}-blocked" \
  '.handoff_id=$id | .role="implementer" | .status="patch_ready" | .receipt_id="impl-1"' \
  "$FIX/receipt-investigator.json" >"$blocked"
bash scripts/handoff-receipt.sh record "$blocked" >/dev/null
if bash scripts/handoff-receipt.sh check-promotion "${run_id}-blocked" 2>/dev/null; then
  echo "expected promotion_blocked"
  exit 1
fi

bad_val="${TMP}/bad-val.json"
jq --arg id "${run_id}-badval" \
  '.handoff_id=$id | .role="verifier" | .status="accepted" | .receipt_id="ver-bad" | .validation={"passed":false,"runner":"tests"}' \
  "$FIX/receipt-investigator.json" >"$bad_val"
bash scripts/handoff-receipt.sh record "$bad_val" >/dev/null
if bash scripts/handoff-receipt.sh check-promotion "${run_id}-badval"; then
  echo "expected failed validation to block promotion"
  exit 1
fi

string_true="${HANDOFF_ROOT}/${run_id}-string"
mkdir -p "$string_true"
jq --arg id "${run_id}-string" \
  '.handoff_id=$id | .role="verifier" | .status="accepted" | .receipt_id="ver-str" | .validation.passed="true"' \
  "$FIX/receipt-investigator.json" >"${string_true}/receipt-ver-str.json"
if bash scripts/handoff-receipt.sh check-promotion "${run_id}-string"; then
  echo "expected string validation.passed to block promotion"
  exit 1
fi

ok="${TMP}/ok.json"
jq --arg id "${run_id}-ok" \
  '.handoff_id=$id | .role="verifier" | .status="accepted" | .receipt_id="ver-1" | .validation={"passed":true,"runner":"tests"}' \
  "$FIX/receipt-investigator.json" >"$ok"
bash scripts/handoff-receipt.sh record "$ok" >/dev/null
bash scripts/handoff-receipt.sh check-promotion "${run_id}-ok" | grep -q promotion_allowed
test -f "${HANDOFF_ROOT}/${run_id}-ok/receipt-ver-1.json"

echo "agent-collection-invariants passed"
