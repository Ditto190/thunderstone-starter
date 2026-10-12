#!/usr/bin/env bash
# Log duplicate subagent launches for the same conversation (KPI: duplicate launches).
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="${ROOT}/.cursor/hooks/state"
LAUNCHES="${STATE_DIR}/recent-launches.jsonl"
METRICS="${STATE_DIR}/collection-metrics.jsonl"
mkdir -p "$STATE_DIR"

input="$(cat)"
if ! command -v jq >/dev/null 2>&1; then
  echo '{"permission":"allow"}'
  exit 0
fi

subagent_type="$(jq -r '.subagent_type // "unknown"' <<<"$input")"
conversation_id="$(jq -r '.conversation_id // .session_id // "unknown"' <<<"$input")"
ts_ms="$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")"

key="${conversation_id}:${subagent_type}"
if [[ -f "$LAUNCHES" ]] && grep -qF "$key" "$LAUNCHES" 2>/dev/null; then
  jq -nc --argjson ts "$ts_ms" --arg key "$key" \
    '{ts_ms:ts,event:"duplicate_launch",launch_key:$key}' >>"$METRICS"
fi

printf '%s %s\n' "$ts_ms" "$key" >>"$LAUNCHES"

echo '{"permission":"allow"}'
exit 0
