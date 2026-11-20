#!/usr/bin/env bash
# sessionStart hook: append one ts-ledger line (timestamp, cwd, session id if given).
# Always silent, always exit 0. failClosed should be false; timeout 5.
{
  _ts=$(date +%Y-%m-%dT%H:%M:%S%z)
  _cwd=$(pwd)
  _sid=""
  _raw=""
  if IFS= read -r _line || [[ -n "${_line:-}" ]]; then
    _raw="$_line"
  fi
  # slurp any remainder so we never block the host
  cat >/dev/null 2>&1 || true
  if [[ -n "$_raw" ]]; then
    _sid=$(printf '%s' "$_raw" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
sid = ""
try:
    d = json.loads(raw)
    if isinstance(d, dict):
        for k in ("session_id", "sessionId", "conversation_id", "conversationId", "id"):
            v = d.get(k)
            if v:
                sid = str(v)
                break
        if not sid:
            ev = d.get("event") or d.get("params") or {}
            if isinstance(ev, dict):
                for k in ("session_id", "sessionId", "conversation_id", "id"):
                    v = ev.get(k)
                    if v:
                        sid = str(v)
                        break
except Exception:
    pass
sys.stdout.write(sid)
' 2>/dev/null || true)
  fi
  _ledger="${TS_HOOK_LEDGER:-/workspace/thunderstone/state/ts-sessions/ledger.tsv}"
  mkdir -p "$(dirname "$_ledger")"
  printf '%s\t%s\t%s\n' "$_ts" "$_cwd" "${_sid:--}" >> "$_ledger"
} >/dev/null 2>&1
exit 0
