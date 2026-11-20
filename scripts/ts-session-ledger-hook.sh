#!/usr/bin/env bash
# sessionStart hook: append one ts-ledger line (ts-session 6-column TSV shape).
# Always silent, always exit 0. failClosed should be false; timeout 5.
(
  set -euo pipefail
  _repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
  if [[ -d "$_repo/../thunderstone" ]]; then
    _state="$_repo/../thunderstone/state/ts-sessions"
  else
    _state="$_repo/.state/ts-sessions"
  fi
  _ledger="${TS_HOOK_LEDGER:-$_state/ledger.tsv}"
  _actor="${TS_HOOK_ACTOR:-${USER:-unknown}}"
  _payload="$(cat)"
  _ts="$(date +%Y-%m-%dT%H:%M:%S%z)"
  _sid="-"
  _cwd="$(pwd)"
  if [[ -n "$_payload" ]]; then
  _sid="$(printf '%s' "$_payload" | python3 -c '
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
sys.stdout.write(sid or "-")
' 2>/dev/null || echo '-')"
  fi
  _detail="cwd=$_cwd"
  _detail="${_detail//$'\t'/ }"
  _detail="${_detail//$'\n'/ }"
  mkdir -p "$(dirname "$_ledger")"
  (
    flock -w 5 9
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$_ts" "$_actor" "sessionStart" "-" "${_sid:--}" "${_detail:0:200}" >>"$_ledger"
  ) 9>>"$_ledger.lock"
) >/dev/null 2>&1 || true
exit 0