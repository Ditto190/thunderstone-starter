#!/usr/bin/env bash
# Desktop Commander helper — status / start / restart / term
# No secrets. One remote chain only (tmux session dc).
set -euo pipefail

ROOT="${THUNDERSTONE_ROOT:-/workspace/thunderstone}"
LOG="$ROOT/artifacts/DC-REMOTE-2026-10-15.log"
SESSION="dc"
TERM_SESSION="dc-term"
DC_LAUNCH='npx -y @wonderwhy-er/desktop-commander@latest remote'

usage() {
  echo "usage: dc-helper.sh {status|start|restart|term}" >&2
  exit 64
}

has_tmux() { command -v tmux >/dev/null 2>&1; }

session_alive() {
  has_tmux && tmux has-session -t "=$SESSION" 2>/dev/null
}

# All PIDs whose cmdline looks like desktop-commander remote (npx/node).
dc_remote_pids() {
  local p cmd comm
  for p in $(pgrep -f 'desktop-commander' 2>/dev/null || true); do
    # tmux's own argv contains the command used to start its pane, so pgrep -f
    # sees the launch wrapper as a false Desktop Commander process. The actual
    # remote chain is the pane's bash/npm/sh/node descendants.
    comm=$(cat "/proc/$p/comm" 2>/dev/null || true)
    [[ "$comm" == "tmux" || "$comm" == "tmux: server" ]] && continue
    cmd=$(tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null || true)
    case "$cmd" in
      *desktop-commander*remote*)
        echo "$p"
        ;;
    esac
  done
}

# Descendants of a PID (inclusive), one per line.
descendants() {
  local pid=$1 kid
  echo "$pid"
  for kid in $(pgrep -P "$pid" 2>/dev/null || true); do
    descendants "$kid"
  done
}

# PIDs belonging to tmux session dc (pane trees).
session_tree_pids() {
  local pane
  session_alive || return 0
  for pane in $(tmux list-panes -t "=$SESSION" -F '#{pane_pid}' 2>/dev/null || true); do
    descendants "$pane"
  done
}

# DC remote PIDs not under tmux dc → duplicates.
duplicate_pids() {
  local tree dc_pid
  tree=$(session_tree_pids | sort -u)
  for dc_pid in $(dc_remote_pids); do
    if ! printf '%s\n' "$tree" | grep -qx "$dc_pid"; then
      # Also treat as in-session if any ancestor is in the tree.
      local walk=$dc_pid in=0
      while [[ -n "$walk" && "$walk" != 0 ]]; do
        if printf '%s\n' "$tree" | grep -qx "$walk"; then
          in=1
          break
        fi
        walk=$(awk '{print $4}' "/proc/$walk/stat" 2>/dev/null || echo 0)
      done
      if [[ $in -eq 0 ]]; then
        echo "$dc_pid"
      fi
    fi
  done
}

log_alerts() {
  [[ -f "$LOG" ]] || { echo "(no log at $LOG)"; return 0; }
  # Last 40 lines; surface offline / disconnect / error (redact URLs/tokens).
  tail -n 40 "$LOG" 2>/dev/null \
    | grep -iE 'offline|disconnect|error|socket closed|Channel error' \
    | sed -E 's#https?://[^[:space:]]+#<URL>#g; s#([Tt]oken|[Kk]ey|[Ss]ecret)[=: ]+[^[:space:]]+#\1=<REDACTED>#g' \
    | tail -n 8 \
    || true
}

cmd_status() {
  local alive=0 dups=0 dc_count=0
  local dup_list dc_list

  if session_alive; then alive=1; fi
  dc_list=$(dc_remote_pids | sort -u)
  dc_count=$(printf '%s\n' "$dc_list" | grep -c . || true)
  [[ -z "${dc_list// }" ]] && dc_count=0
  dup_list=$(duplicate_pids | sort -u)
  dups=$(printf '%s\n' "$dup_list" | grep -c . || true)
  [[ -z "${dup_list// }" ]] && dups=0

  if [[ $alive -eq 1 && $dups -eq 0 && $dc_count -ge 1 ]]; then
    echo "dc-helper: green (tmux=$SESSION dc_pids=$dc_count)"
    exit 0
  fi

  echo "dc-helper: status"
  echo "  tmux_$SESSION: $([[ $alive -eq 1 ]] && echo alive || echo absent)"
  echo "  dc_remote_pids: ${dc_count} (${dc_list:-none})"
  echo "  duplicates_outside_tmux: ${dups} (${dup_list:-none})"
  echo "  log_alerts:"
  log_alerts | sed 's/^/    /' || echo "    (none)"

  if [[ $dups -gt 0 ]]; then
    exit 2
  fi
  exit 1
}

cmd_start() {
  local existing
  existing=$(dc_remote_pids | sort -u)
  if [[ -n "$existing" ]]; then
    echo "dc-helper: refuse start — DC already running: $existing" >&2
    echo "  use: dc-helper.sh status | restart" >&2
    exit 2
  fi
  if session_alive; then
    echo "dc-helper: refuse start — tmux session '$SESSION' already present (no DC pid? check status)" >&2
    exit 2
  fi
  if ! has_tmux; then
    echo "dc-helper: tmux missing" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$LOG")"
  # Detached session: DO_NOT_TRACK=1, tee into artifact log.
  tmux new-session -d -s "$SESSION" \
    "export DO_NOT_TRACK=1; $DC_LAUNCH 2>&1 | tee -a '$LOG'"
  sleep 1
  if session_alive; then
    echo "dc-helper: started tmux=$SESSION"
    exit 0
  fi
  echo "dc-helper: start failed — session not present after launch" >&2
  exit 1
}

cmd_restart() {
  local outside
  outside=$(duplicate_pids | sort -u)
  if [[ -n "$outside" ]]; then
    echo "dc-helper: warning — DC pids outside tmux $SESSION (not killed): $outside" >&2
  fi
  if session_alive; then
    tmux kill-session -t "=$SESSION" 2>/dev/null || true
    # Wait briefly for clean exit; do not pkill outside session.
    sleep 1
  fi
  # After kill, any leftover under old session should be gone; refuse if DC still up.
  local leftover
  leftover=$(dc_remote_pids | sort -u)
  if [[ -n "$leftover" ]]; then
    echo "dc-helper: restart blocked — DC still running outside/after kill: $leftover" >&2
    echo "  report only; will not kill those pids" >&2
    exit 2
  fi
  cmd_start
}

cmd_term() {
  if ! has_tmux; then
    echo "dc-helper: tmux missing" >&2
    exit 1
  fi
  if tmux has-session -t "=$TERM_SESSION" 2>/dev/null; then
    if [[ -t 0 && -t 1 ]]; then
      echo "dc-helper: attaching $TERM_SESSION"
      exec tmux attach-session -t "=$TERM_SESSION"
    fi
    echo "dc-helper: tmux=$TERM_SESSION already present (detached)"
    exit 0
  fi
  tmux new-session -d -s "$TERM_SESSION" -c "$ROOT" bash
  if [[ -t 0 && -t 1 ]]; then
    echo "dc-helper: created+attach $TERM_SESSION"
    exec tmux attach-session -t "=$TERM_SESSION"
  fi
  echo "dc-helper: started tmux=$TERM_SESSION (detached)"
  exit 0
}

[[ $# -ge 1 ]] || usage
case "$1" in
  status)  cmd_status ;;
  start)   cmd_start ;;
  restart) cmd_restart ;;
  term)    cmd_term ;;
  *)       usage ;;
esac
