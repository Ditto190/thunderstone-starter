#!/usr/bin/env bash
# Record or idempotently ignore handoff receipts (protocol v1).
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: handoff-receipt.sh record <receipt.json> | check-promotion <handoff_id>" >&2
  exit 2
}

ensure_jq() {
  command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }
}

record() {
  local src="${1:?receipt file}"
  ensure_jq
  local handoff_id receipt_id dest dir
  handoff_id="$(jq -r '.handoff_id // empty' "$src")"
  receipt_id="$(jq -r '.receipt_id // empty' "$src")"
  [[ -n "$handoff_id" && -n "$receipt_id" ]] || { echo "handoff_id and receipt_id required" >&2; exit 1; }
  dir="workspace/handoffs/${handoff_id}"
  mkdir -p "$dir"
  dest="${dir}/receipt-${receipt_id}.json"
  if [[ -f "$dest" ]]; then
    echo "duplicate_ignored receipt_id=${receipt_id}"
    exit 0
  fi
  jq -c '.' "$src" >"$dest"
  echo "recorded receipt_id=${receipt_id}"
}

check_promotion() {
  local handoff_id="${1:?handoff_id}"
  ensure_jq
  local dir="workspace/handoffs/${handoff_id}"
  [[ -d "$dir" ]] || { echo "promotion_blocked missing_handoff_dir"; exit 1; }
  local verifier
  verifier="$(find "$dir" -maxdepth 1 -name '*.json' -print0 | xargs -0 jq -s '
    map(select(.role=="verifier")) | sort_by(.created_at_ms) | last // empty
  ' 2>/dev/null || echo '{}')"
  if [[ "$verifier" == "{}" || "$verifier" == "null" ]]; then
    echo "promotion_blocked no_verifier_receipt"
    exit 1
  fi
  local status passed
  status="$(jq -r '.status // empty' <<<"$verifier")"
  passed="$(jq -r '.validation.passed // false' <<<"$verifier")"
  if [[ "$status" != "accepted" || "$passed" != "true" ]]; then
    echo "promotion_blocked status=${status} validation_passed=${passed}"
    exit 1
  fi
  echo "promotion_allowed"
}

case "${1:-}" in
  record) record "${2:-}" ;;
  check-promotion) check_promotion "${2:-}" ;;
  *) usage ;;
esac
