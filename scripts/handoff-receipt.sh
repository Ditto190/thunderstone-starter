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

require_id() {
  local id="$1" label="$2"
  [[ -n "$id" ]] || { echo "${label} required" >&2; exit 1; }
  [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$id" != *..* ]] || {
    echo "unsafe ${label}" >&2
    exit 1
  }
}

handoff_root() {
  printf '%s\n' "${HANDOFF_ROOT:-workspace/handoffs}"
}

record() {
  local src="${1:?receipt file}"
  ensure_jq
  local handoff_id receipt_id dest dir tmp root
  handoff_id="$(jq -r '.handoff_id // empty' "$src")"
  receipt_id="$(jq -r '.receipt_id // empty' "$src")"
  require_id "$handoff_id" handoff_id
  require_id "$receipt_id" receipt_id
  jq -e '
    .protocol_version == 1
    and (
      (.role == "investigator" and .status == "validated")
      or (.role == "implementer" and (.status == "patch_ready" or .status == "blocked"))
      or (.role == "verifier" and (.status == "accepted" or .status == "rejected" or .status == "promotion_blocked"))
    )
    and ((.validation.passed | type) == "boolean")
  ' "$src" >/dev/null || { echo "invalid receipt fields" >&2; exit 1; }
  root="$(handoff_root)"
  dir="${root}/${handoff_id}"
  mkdir -p "$dir"
  dest="${dir}/receipt-${receipt_id}.json"
  tmp="$(mktemp "${dir}/.receipt-${receipt_id}.XXXXXX")"
  jq -c '.' "$src" >"$tmp"
  if ! ln "$tmp" "$dest" 2>/dev/null; then
    rm -f "$tmp"
    if [[ -f "$dest" ]]; then
      echo "duplicate_ignored receipt_id=${receipt_id}"
      exit 0
    fi
    echo "record failed" >&2
    exit 1
  fi
  rm -f "$tmp"
  echo "recorded receipt_id=${receipt_id}"
}

check_promotion() {
  local handoff_id="${1:?handoff_id}"
  ensure_jq
  require_id "$handoff_id" handoff_id
  local dir root
  root="$(handoff_root)"
  dir="${root}/${handoff_id}"
  [[ -d "$dir" ]] || { echo "promotion_blocked missing_handoff_dir"; exit 1; }
  local verifier
  verifier="$(find "$dir" -maxdepth 1 -name 'receipt-*.json' -print0 | xargs -0 jq -s '
    map(select(.role=="verifier")) | sort_by(.created_at_ms) | last // empty
  ' 2>/dev/null || echo '{}')"
  if [[ "$verifier" == "{}" || "$verifier" == "null" || -z "$verifier" ]]; then
    echo "promotion_blocked no_verifier_receipt"
    exit 1
  fi
  local status passed
  status="$(jq -r '.status // empty' <<<"$verifier")"
  passed="$(jq -r 'if (.validation.passed | type) == "boolean" then .validation.passed else false end' <<<"$verifier")"
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
