#!/usr/bin/env bash
# Fail-open lifecycle observer for Cursor and Grok hook events.
# sessionStart also returns the existing stage-router advisory.
set -u

SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

payload="$(cat 2>/dev/null || true)"
event="${1:-}"
if [ -z "$event" ] && [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  event="$(printf '%s' "$payload" | jq -r '(.hook_event_name // .hookEventName // .event // empty)' 2>/dev/null || true)"
fi

# Forward the global payload to lean-ctx hook observe when both tools are available.
# Takes no arguments; timeout requests termination after one second.
# Discard observer output and return success if tools are missing or observation fails.
observe_lean_ctx() {
  command -v lean-ctx >/dev/null 2>&1 || return 0
  command -v timeout >/dev/null 2>&1 || return 0
  printf '%s' "$payload" | timeout 1 lean-ctx hook observe >/dev/null 2>&1 || true
}

observe_lean_ctx

case "$event" in
  sessionStart|SessionStart)
    if out="$(bash "${SCRIPT_DIR}/stage-router.sh" 2>/dev/null)" && [ -n "$out" ]; then
      printf '%s\n' "$out"
    else
      printf '{}\n'
    fi
    ;;
  *)
    printf '{}\n'
    ;;
esac
exit 0
