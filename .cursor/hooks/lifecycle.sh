#!/usr/bin/env bash
# Unified lifecycle dispatcher for Cursor / Grok-compatible hook events.
# Forwards payloads to lean-ctx when installed; fail-open unless FAIL_CLOSED=1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVENT="${1:-unknown}"
INPUT="$(cat || true)"
FAIL_CLOSED="${FAIL_CLOSED:-0}"

emit_empty() {
  printf '{}\n'
}

run_stage_router() {
  if [ -f "$ROOT/.cursor/hooks/stage-router.sh" ]; then
    printf '%s' "$INPUT" | bash "$ROOT/.cursor/hooks/stage-router.sh" 2>/dev/null || emit_empty
  else
    emit_empty
  fi
}

observe_lean_ctx() {
  if ! command -v lean-ctx >/dev/null 2>&1; then
    return 0
  fi
  if ! lean-ctx hook observe --help >/dev/null 2>&1; then
    return 0
  fi
  if ! printf '%s' "$INPUT" | lean-ctx hook observe --event "$EVENT" >/dev/null 2>&1; then
    [ "$FAIL_CLOSED" = 1 ] && return 1
  fi
  return 0
}

case "$EVENT" in
  sessionStart)
    run_stage_router
    observe_lean_ctx || { [ "$FAIL_CLOSED" = 1 ] && exit 1; }
    ;;
  *)
    observe_lean_ctx || { [ "$FAIL_CLOSED" = 1 ] && exit 1; }
    emit_empty
    ;;
esac

exit 0
