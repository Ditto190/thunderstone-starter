#!/usr/bin/env bash
# Deterministic coordination invariants for agent collections (pilot gates).
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FIX="${ROOT}/tests/fixtures/handoff"
TMP="${ROOT}/workspace/handoffs/_invariant_test"
rm -rf "$TMP"
mkdir -p "$TMP/handoff_id"

# Gate: duplicate receipt ignored
R1="${FIX}/receipt-investigator.json"
cp "$R1" "$TMP/handoff_id/r1.json"
bash scripts/handoff-receipt.sh record "$TMP/handoff_id/r1.json" >/dev/null
out2="$(bash scripts/handoff-receipt.sh record "$TMP/handoff_id/r1.json")"
grep -q duplicate_ignored <<<"$out2"

# Gate: failed validation blocks promotion (no verifier accepted)
hid="pilot-blocked"
mkdir -p "workspace/handoffs/${hid}"
cp "${FIX}/receipt-investigator.json" "workspace/handoffs/${hid}/inv.json"
jq '.role="implementer"|.status="patch_ready"|.receipt_id="impl-1"' "${FIX}/receipt-investigator.json" \
  >"workspace/handoffs/${hid}/impl.json"
if bash scripts/handoff-receipt.sh check-promotion "$hid" 2>/dev/null; then
  echo "expected promotion_blocked"
  exit 1
fi

# Gate: accepted verifier allows promotion
hid2="pilot-ok"
mkdir -p "workspace/handoffs/${hid2}"
cp "${FIX}/receipt-investigator.json" "workspace/handoffs/${hid2}/inv.json"
jq '.role="verifier"|.status="accepted"|.receipt_id="ver-1"|.validation={"passed":true,"runner":"tests"}' \
  "${FIX}/receipt-investigator.json" >"workspace/handoffs/${hid2}/ver.json"
bash scripts/handoff-receipt.sh check-promotion "$hid2" | grep -q promotion_allowed

# Resume fixture: interrupted handoff dir still readable
test -f "workspace/handoffs/${hid2}/ver.json"

rm -rf "$TMP" "workspace/handoffs/pilot-blocked" "workspace/handoffs/pilot-ok" "workspace/handoffs/pilot-fixture"
echo "agent-collection-invariants passed"
