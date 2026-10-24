#!/usr/bin/env bash
# Log duplicate subagent launches for the same handoff and agent type.
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="${ROOT}/.cursor/hooks/state"
LAUNCHES="${STATE_DIR}/recent-launches.jsonl"
METRICS="${STATE_DIR}/collection-metrics.jsonl"
LOCK="${STATE_DIR}/launches.lock"
mkdir -p "$STATE_DIR"

input="$(cat)"
if ! command -v jq >/dev/null 2>&1; then
  echo '{"permission":"allow"}'
  exit 0
fi

subagent_type="$(jq -r '.subagent_type // "unknown"' <<<"$input")"
task_id="$(jq -r '.handoff_id // .task_id // empty' <<<"$input")"
if ts_ms="$(date +%s%3N 2>/dev/null)" && [[ "$ts_ms" =~ ^[0-9]{13}$ ]]; then
  :
else
  ts_ms="$(date +%s)000"
fi

release_lock() {
  if [[ "${LOCK_MODE:-}" == "flock" ]]; then
    flock -u 9 || true
  elif [[ "${LOCK_MODE:-}" == "mkdir" ]]; then
    rmdir "${LOCK}.d" 2>/dev/null || true
  fi
}
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK"
  flock 9
  LOCK_MODE="flock"
else
  while ! mkdir "${LOCK}.d" 2>/dev/null; do
    sleep 0.05
  done
  LOCK_MODE="mkdir"
fi
trap release_lock EXIT
if [[ -n "$task_id" ]]; then
  key="${task_id}:${subagent_type}"
  if [[ -f "$LAUNCHES" ]] && jq -se --arg key "$key" 'any(.[]; .key == $key)' "$LAUNCHES" >/dev/null; then
    jq -nc --argjson ts "$ts_ms" --arg key "$key" \
      '{ts_ms:$ts,event:"duplicate_launch",launch_key:$key}' >>"$METRICS"
  fi
  jq -nc --argjson ts "$ts_ms" --arg key "$key" '{ts_ms:$ts,key:$key}' >>"$LAUNCHES"
fi
release_lock
trap - EXIT

echo '{"permission":"allow"}'
exit 0
