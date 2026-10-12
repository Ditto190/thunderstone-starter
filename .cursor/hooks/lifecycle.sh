#!/usr/bin/env bash
# Thunderstone lifecycle dispatcher. Fail-open: never block the agent.
set -u

ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
CONFIG="${LIFECYCLE_CONFIG:-$ROOT/.cursor/hooks/lifecycle.config.json}"
ROUTER="${LIFECYCLE_STAGE_ROUTER:-$ROOT/.cursor/hooks/stage-router.sh}"

log() {
  printf 'lifecycle: %s\n' "$*" >&2
}

trace() {
  if [ -n "${LIFECYCLE_TRACE:-}" ]; then
    printf '%s\n' "$1" >>"$LIFECYCLE_TRACE"
  fi
}

canonical_event() {
  case "$1" in
    sessionStart | SessionStart) printf '%s\n' sessionStart ;;
    sessionEnd | SessionEnd) printf '%s\n' sessionEnd ;;
    beforeSubmitPrompt | UserPromptSubmit) printf '%s\n' beforeSubmitPrompt ;;
    preToolUse | PreToolUse) printf '%s\n' preToolUse ;;
    postToolUse | PostToolUse) printf '%s\n' postToolUse ;;
    postToolUseFailure | PostToolUseFailure) printf '%s\n' postToolUseFailure ;;
    subagentStart | SubagentStart) printf '%s\n' subagentStart ;;
    subagentStop | SubagentStop) printf '%s\n' subagentStop ;;
    preCompact | PreCompact) printf '%s\n' preCompact ;;
    stop | Stop) printf '%s\n' stop ;;
    permissionDenied | PermissionDenied) printf '%s\n' permissionDenied ;;
    stopFailure | StopFailure) printf '%s\n' stopFailure ;;
    notification | Notification) printf '%s\n' notification ;;
    postCompact | PostCompact) printf '%s\n' postCompact ;;
    *) printf '%s\n' "$1" ;;
  esac
}

emit_empty() {
  printf '{}\n'
}

event="${1:-${GROK_HOOK_EVENT:-}}"
payload="$(cat || true)"
if [ -z "$event" ] && command -v jq >/dev/null 2>&1; then
  parsed="$(printf '%s' "$payload" | jq -r '.hookEventName // .hook_event_name // empty' 2>/dev/null || true)"
  event="$parsed"
fi
canonical="$(canonical_event "$event")"

if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  enabled="$(jq -r --arg event "$canonical" 'if (.hooks[$event] == false) then "false" else "true" end' "$CONFIG" 2>/dev/null || true)"
  if [ "$enabled" = "false" ]; then
    log "hook $canonical disabled by config"
    emit_empty
    exit 0
  fi
fi

observe_event="$event"
if [ -z "$observe_event" ]; then
  observe_event="$canonical"
fi

trace "lean-ctx"
lean_bin="${LIFECYCLE_LEAN_CTX_BIN:-}"
if [ -z "$lean_bin" ] && command -v lean-ctx >/dev/null 2>&1; then
  lean_bin="$(command -v lean-ctx)"
fi
if [ -z "$lean_bin" ]; then
  log "lean-ctx missing; skip observe"
else
  if command -v timeout >/dev/null 2>&1; then
    printf '%s' "$payload" | timeout 1 "$lean_bin" hook observe "$observe_event" >/dev/null || log "lean-ctx observe failed"
  else
    printf '%s' "$payload" | "$lean_bin" hook observe "$observe_event" >/dev/null || log "lean-ctx observe failed"
  fi
fi

if [ "$canonical" = "sessionStart" ]; then
  trace "stage-router"
  router_out="$(printf '%s' "$payload" | bash "$ROUTER" 2>/dev/null || true)"
  if printf '%s' "$router_out" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$router_out"
  else
    log "stage-router output ignored"
    emit_empty
  fi
else
  emit_empty
fi
exit 0
