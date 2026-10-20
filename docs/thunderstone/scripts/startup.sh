#!/usr/bin/env bash
# Thunderstone startup: run the health check in the foreground, then print the START-HERE pointer.
# Prints the START-HERE pointer (set STARTUP_QUIET=1 to stay silent on green).
# Exit code mirrors health.sh (non-zero = wake Chief Thunderstone with the printed artifact path).
#
# TRIGGERS (events only; there is no schedule, no cron and no time-based routine):
#   - Cursor CLI/IDE: the ~/.cursor/hooks.json `sessionStart` hook runs `bash $WORKSPACE/thunderstone/scripts/health.sh --bg`
#     (failClosed false, timeoutSec 5). It detaches at once, so nothing waits on it.
#   - Grok Bot bots (no hook file): on the first work turn of a session run `bash $WORKSPACE/thunderstone/scripts/health.sh --bg`
#     once, do not wait for it, and read $WORKSPACE/thunderstone/state/health-last.json only if it fails or a task needs the VM.
#   - A once-per-session / 30-minute min-interval guard in health.sh stops repeated turns from rerunning it.
#   This script is the manual, foreground variant: run it by hand when you want the result printed now.
if [ -n "${WORKSPACE_ROOT:-}" ]; then
  WORKSPACE=$WORKSPACE_ROOT
else
  WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fi
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
START_HERE="${START_HERE_PATH:-$WORKSPACE/thunderstone/.context/START-HERE.md}"

out="$(bash "$HERE/health.sh" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  printf '%s\n' "$out"
  echo "START-HERE: $START_HERE (health failed; read the evidence path above first)"
  exit "$rc"
fi
# Surface non-fatal conditions (e.g. Cursor usage limit) from today's log once, if present.
lg="$WORKSPACE/thunderstone/reports/health-$(TZ=Australia/Sydney date +%Y%m%d).log"
if [ -f "$lg" ] && tail -n1 "$lg" | grep -q 'WARN:'; then tail -n1 "$lg"; fi
if [ "${STARTUP_QUIET:-0}" != "1" ]; then echo "START-HERE: $START_HERE"; fi
exit 0
