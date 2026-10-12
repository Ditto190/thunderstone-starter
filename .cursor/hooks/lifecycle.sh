#!/usr/bin/env bash
# Fail-open lifecycle dispatcher for Cursor and Grok hook events.
# sessionStart also runs the stage router. LeanCTX observation is best-effort.
set -u

event="${1:-${THUNDERSTONE_HOOK_EVENT:-}}"
payload="$(cat || true)"

if [ -z "$event" ]; then
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // .hookEventName // .event // empty' 2>/dev/null || true)"
fi

observe_lean_ctx() {
  local bin=""
  if command -v lean-ctx >/dev/null 2>&1; then
    bin="lean-ctx"
  elif [ -n "${HOME:-}" ] && [ -x "${HOME}/.local/bin/lean-ctx" ]; then
    bin="${HOME}/.local/bin/lean-ctx"
  else
    return 0
  fi
  if [ -z "$event" ]; then
    return 0
  fi
  if command -v timeout >/dev/null 2>&1; then
    printf '%s' "$payload" | timeout 2 "$bin" hook observe >/dev/null 2>&1 || true
  else
    printf '%s' "$payload" | "$bin" hook observe >/dev/null 2>&1 || true
  fi
}

observe_lean_ctx || true

case "$event" in
  sessionStart|SessionStart)
    hook_dir="$(cd "$(dirname -- "$0")" && pwd)"
    if ! printf '%s' "$payload" | bash "${hook_dir}/stage-router.sh"; then
      printf '{}\n'
    fi
    ;;
  *)
    printf '{}\n'
    ;;
esac
exit 0
