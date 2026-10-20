#!/usr/bin/env bash
# Append agent-collection KPI events to collection-metrics.jsonl (fail-open).
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="${ROOT}/.cursor/hooks/state"
METRICS="${STATE_DIR}/collection-metrics.jsonl"
mkdir -p "$STATE_DIR"

input="$(cat)"
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

event="$(jq -r '.hook_event_name // "unknown"' <<<"$input")"
ts_ms="$(jq -r '.timestamp_ms // empty' <<<"$input")"
if [[ -z "$ts_ms" || "$ts_ms" == "null" ]]; then
  ts_ms="$(date +%s%3N 2>/dev/null || true)"
  if [[ ! "$ts_ms" =~ ^[0-9]{13}$ ]]; then
    ts_ms="$(date +%s)000"
  fi
fi

subagent_type="$(jq -r '.subagent_type // .tool_name // empty' <<<"$input" 2>/dev/null || true)"
conversation_id="$(jq -r '.conversation_id // .session_id // empty' <<<"$input" 2>/dev/null || true)"
status="$(jq -r '.status // empty' <<<"$input" 2>/dev/null || true)"
failure_type="$(jq -r '.failure_type // empty' <<<"$input" 2>/dev/null || true)"

line="$(jq -nc \
  --arg event "$event" \
  --argjson ts "$ts_ms" \
  --arg subagent_type "${subagent_type:-}" \
  --arg conversation_id "${conversation_id:-}" \
  --arg status "${status:-}" \
  --arg failure_type "${failure_type:-}" \
  '{ts_ms:$ts,event:$event,subagent_type:(if $subagent_type=="" then null else $subagent_type end),conversation_id:(if $conversation_id=="" then null else $conversation_id end),status:(if $status=="" then null else $status end),failure_type:(if $failure_type=="" then null else $failure_type end)}')"

printf '%s\n' "$line" >>"$METRICS"
exit 0
