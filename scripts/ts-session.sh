#!/usr/bin/env bash
# ts-session.sh — DRAFT (2026-11-20, Chief / FORGE). Not installed. Not in PATH.
# Shared, bot-drivable Cursor CLI (`agent`) sessions on the box.
#   Interactive TUI  -> named tmux session on a dedicated shared socket (-L $TS_SOCKET).
#   Token-cheap turn -> headless `agent -p --resume <chatId> --output-format json` (final text only).
# Every verb appends one TSV line to an append-only ledger. No secrets are logged.
# Refs: cursor.com/docs/cli/headless, cursor.com/docs/cli/reference/output-format,
#       cursor.com/docs/cli/overview (Sessions), tmux(1) send-keys -l / capture-pane -p -J -S.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

TS_SOCKET="${TS_SOCKET:-ts-shared}"                  # tmux -L name; all bots run as uid box
_ts_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ -z "${TS_STATE:-}" ]]; then
  if [[ -d "$_ts_repo/../thunderstone" ]]; then
    TS_STATE="$_ts_repo/../thunderstone/state/ts-sessions"
  else
    TS_STATE="$_ts_repo/.state/ts-sessions"
  fi
fi
unset _ts_repo
TS_LEDGER="${TS_LEDGER:-$TS_STATE/ledger.tsv}"
TS_ACTOR="${TS_ACTOR:-${USER:-unknown}}"             # set by the calling bot, e.g. Cursor-Runner
TS_TIMEOUT="${TS_TIMEOUT:-180}"
TS_PROTECTED_RE='^(dc|thunderstone|thunderstone-worker)$'
AUTH_RE='Authentication required|Not logged in|Please log in|agent login'

die() { echo "ts-session: $*" >&2; exit "${2:-1}"; }
tm() { tmux -L "$TS_SOCKET" "$@"; }
now() { date +%Y-%m-%dT%H:%M:%S%z; }

ledger() { # verb name chat detail
  mkdir -p "$(dirname "$TS_LEDGER")"
  local d="${4//$'\t'/ }"; d="${d//$'\n'/ }"
  ( flock -w 5 9; printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now)" "$TS_ACTOR" "$1" "$2" "${3:--}" "${d:0:200}" >>"$TS_LEDGER" ) 9>>"$TS_LEDGER.lock"
}

check_name() {
  # tmux normalizes '.' to '_' in session names; reject '.' to keep =NAME: targets consistent.
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,40}$ ]] || die "bad session name: $1" 2
  [[ "$1" =~ $TS_PROTECTED_RE ]] && die "refusing protected session: $1" 2
  return 0
}
chat_lock_file() { # CHAT_ID -> path under TS_STATE/locks
  local safe="${1//[^A-Za-z0-9_-]/_}"
  mkdir -p "$TS_STATE/locks"
  printf '%s\n' "$TS_STATE/locks/chat-${safe}.lock"
}
chat_of() { tm show-options -t "=$1:" -qv @ts_chat 2>/dev/null || true; }

preflight() { # exit 77 = auth missing (fail fast, no retry)
  command -v tmux >/dev/null || die "tmux missing" 1
  command -v agent >/dev/null || die "agent CLI missing" 1
  local j
  j="$(timeout 20 agent status --format json 2>/dev/null || true)"
  # `agent status` exits 0 even when logged out; parse the JSON instead.
  [[ "$(jq -r '.isAuthenticated // false' <<<"$j" 2>/dev/null)" == "true" ]] || {
    ledger preflight - - "auth=missing"; die "AUTH_MISSING: run 'agent login' (DT) — no retry" 77; }
}

clean() { # strip ANSI, box-drawing, trailing space, blank runs
  sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/[─│┌┐└┘├┤┬┴┼╭╮╯╰━┃]+/ /g; s/[[:space:]]+$//' \
    | awk 'NF{print; b=0; next} !b{print ""; b=1}'
}


wait_pane_has() { # NAME NEEDLE SECS — 0 if capture-pane shows NEEDLE (fixed string)
  local name="${1:?}" needle="${2:?}" max="${3:-5}" start now pane
  start=$(date +%s)
  while true; do
    pane="$(tm capture-pane -t "=$name:" -p -J -S -40 2>/dev/null || true)"
    if [[ -n "$needle" ]] && grep -Fq -- "$needle" <<<"$pane"; then
      return 0
    fi
    now=$(date +%s)
    if (( now - start >= max )); then
      return 1
    fi
    sleep 0.1
  done
}

_start_session() { # name chat mode cwd force raw launch
  local name="$1" chat="$2" mode="$3" cwd="$4" force="$5" raw="$6" launch="$7"
  tm new-session -d -s "$name" -x 200 -y 50 -c "$cwd" "$launch"
  tm set-option -t "=$name:" @ts_chat "${chat:--}" >/dev/null
  tm set-option -t "=$name:" @ts_owner "$TS_ACTOR" >/dev/null
  tm set-option -w -t "=$name:" remain-on-exit on >/dev/null 2>&1 || true
  if [[ -z "$raw" ]]; then
    wait_pane_has "$name" "→" 20 || echo "ts-session: start: input line not seen within 20s" >&2
  fi
  ledger start "$name" "${chat:--}" "cwd=$cwd mode=${mode:-agent} force=${force:-0} raw=${raw:+1}"
  echo "started $name chat=${chat:--} socket=$TS_SOCKET"
}

cmd_start() { # start NAME [--chat ID|--new-chat] [--mode ask|plan] [--cwd DIR] [--force] [--cmd 'raw']
  local name="${1:?name}"; shift; check_name "$name"
  local chat="" mode="" cwd="$PWD" force="" raw="" newchat="" launch lockf s
  while (($#)); do case "$1" in
    --chat) chat="$2"; shift 2;; --new-chat) newchat=1; shift;;
    --mode) mode="$2"; shift 2;; --cwd) cwd="$2"; shift 2;;
    --force) force=1; shift;; --cmd) raw="$2"; shift 2;;
    *) die "unknown arg $1" 2;; esac; done
  tm has-session -t "=$name" 2>/dev/null && die "session exists: $name" 3
  if [[ -n "$raw" ]]; then launch="$raw"
  else
    preflight
    # create-chat in the SAME cwd: chats are stored per workspace (~/.cursor/chats/<hash>/<chatId>).
    # Smoke 2026-11-20: a chat created in the repo root then resumed from /tmp/... sat queued ("→ prompt") for 120s.
    [[ -n "$newchat" ]] && chat="$(cd "$cwd" && timeout 30 agent create-chat | tr -d '[:space:]')"
    launch="exec agent --trust"
    [[ -n "$chat" ]]  && launch+=" --resume $(printf %q "$chat")"
    [[ -n "$mode" ]]  && launch+=" --mode $(printf %q "$mode")"
    [[ -n "$force" ]] && launch+=" --force"
  fi
  if [[ -n "$chat" ]]; then
    lockf="$(chat_lock_file "$chat")"
    ( flock -w 30 9 || die "chat $chat busy (single-writer)" 5
      for s in $(tm list-sessions -F '#S' 2>/dev/null || true); do
        [[ "$(chat_of "$s")" == "$chat" ]] && die "chat $chat is live in session $s" 5
      done
      _start_session "$name" "$chat" "$mode" "$cwd" "$force" "$raw" "$launch"
    ) 9>"$lockf"
  else
    _start_session "$name" "$chat" "$mode" "$cwd" "$force" "$raw" "$launch"
  fi
}

cmd_send() { # send NAME TEXT  (literal text, then Enter; one writer at a time)
  local name="${1:?name}" text="${2:?text}"; check_name "$name"
  tm has-session -t "=$name" 2>/dev/null || die "no session $name" 4
  mkdir -p "$TS_STATE"
  ( flock -w 30 8 || die "send lock busy: $name" 5
    tm capture-pane -t "=$name:" -p -J -S - 2>/dev/null >"$TS_STATE/$name.wait.snap" || true
    tm send-keys -t "=$name:" -l -- "$text"
    local vis="$text"
    (( ${#vis} > 40 )) && vis="${vis: -40}"
    wait_pane_has "$name" "$vis" 5 || true
    sleep 1
    tm send-keys -t "=$name:" Enter
  ) 8>"$TS_STATE/$name.send.lock"
  ledger send "$name" "$(chat_of "$name")" "chars=${#text}"
}

_pane_since_send() { # NAME -> pane text after last send snapshot (or full pane)
  local name="${1:?name}" snapf full snap
  snapf="$TS_STATE/$name.wait.snap"
  full="$(tm capture-pane -p -J -t "=$name:" -S - 2>/dev/null)" || return 1
  if [[ -f "$snapf" ]]; then
    snap="$(<"$snapf")"
    if [[ -n "$snap" && "$full" == "$snap"* ]]; then
      printf '%s' "${full#"$snap"}"
    else
      tail -n 200 <<<"$full"
    fi
  else
    printf '%s\n' "$full"
  fi
}

cmd_wait() { # wait NAME REGEX [TIMEOUT]  -> 0 match, 77 auth, 124 timeout, 6 pane dead
  local name="${1:?name}" re="${2:?regex}" t="${3:-$TS_TIMEOUT}" i=0 buf
  check_name "$name"
  while ((i < t)); do
    buf="$(_pane_since_send "$name")" || die "no session $name" 4
    grep -qE -- "$re" <<<"$buf" && { ledger wait "$name" "$(chat_of "$name")" "ok after ${i}s"; return 0; }
    grep -qE -- "$AUTH_RE" <<<"$buf" && { ledger wait "$name" - "auth-fail after ${i}s"; die "AUTH_FAIL in $name — stop, no retry" 77; }
    # A prompt still shown as queued ("→ text") after 60s = agent busy/stuck; fail fast, do not resend.
    ((i >= 60)) && grep -qE '^[[:space:]]*→ ' <<<"$buf" && ! grep -qE -- "$re" <<<"$buf" && {
      ledger wait "$name" - "queued-stuck ${i}s"; die "prompt still queued after ${i}s in $name — stop, report" 7; }
    [[ "$(tm display-message -p -t "=$name:" '#{pane_dead}' 2>/dev/null)" == 1 ]] && { ledger wait "$name" - "pane dead"; die "pane exited: $name" 6; }
    sleep 1; i=$((i+1))
  done
  ledger wait "$name" - "timeout ${t}s"; die "timeout ${t}s waiting for /$re/ in $name" 124
}

cmd_read() { # read NAME [LINES]  -> cleaned tail; ~token estimate on stderr; TS_LEANCTX=1 pipes via lean-ctx -c
  local name="${1:?name}" n="${2:-40}" out f
  check_name "$name"
  out="$(tm capture-pane -p -J -t "=$name:" -S -"$n" | clean | tail -n "$n")" || die "no session $name" 4
  if [[ "${TS_LEANCTX:-0}" == 1 ]] && command -v lean-ctx >/dev/null; then
    f="$(mktemp)"; printf '%s\n' "$out" >"$f"; out="$(lean-ctx -c "cat $f" 2>/dev/null || cat "$f")"; rm -f "$f"
  fi
  printf '%s\n' "$out"
  echo "~tokens=$(( (${#out} + 3) / 4 ))" >&2
  ledger read "$name" "$(chat_of "$name")" "lines=$n chars=${#out}"
}

cmd_ask() { # ask CHAT_ID|new TEXT [--mode ask]  headless, final text only (cheapest turn); "new" prints session_id to stderr
  local chat="${1:?chatId}" text="${2:?text}"; shift 2
  local mode=() s lockf resolved="$chat"
  [[ "${1:-}" == --mode ]] && mode=(--mode "$2")
  # Single writer per chat: flock from live-session check through agent -p (exit 5 if busy).
  lockf="$(chat_lock_file "$chat")"
  ( flock -w 30 9 || die "chat $chat busy (single-writer)" 5
    if [[ "$chat" != new ]]; then
      for s in $(tm list-sessions -F '#S' 2>/dev/null || true); do
        [[ "$(chat_of "$s")" == "$chat" ]] && die "chat $chat is live in session $s" 5
      done
    fi
    preflight
    local j rc=0
    local res=(--resume "$chat"); [[ "$chat" == new ]] && res=()
    j="$(timeout "$TS_TIMEOUT" agent -p --trust "${res[@]}" "${mode[@]}" --output-format json "$text" 2>&1)" || rc=$?
    grep -qE -- "$AUTH_RE" <<<"$j" && { ledger ask - "$chat" "auth-fail"; die "AUTH_FAIL — stop, no retry" 77; }
    ((rc == 0)) || { ledger ask - "$chat" "rc=$rc"; die "agent -p rc=$rc: ${j:0:200}" "$rc"; }
    jq -r '.result' <<<"$j"
    [[ "$chat" == new ]] && { resolved="$(jq -r '.session_id' <<<"$j")"; echo "session_id=$resolved" >&2; }
    ledger ask - "$resolved" "ms=$(jq -r '.duration_ms' <<<"$j") chars=$(jq -r '.result|length' <<<"$j")"
  ) 9>"$lockf"
}

cmd_status() {
  tm list-sessions -F '#S	#{session_created}	#{?session_attached,attached,detached}	#{pane_dead}	#{@ts_chat}	#{@ts_owner}' 2>/dev/null \
    | awk -F'\t' 'BEGIN{print "name\tcreated\tattached\tdead\tchat\towner"} {print}' || echo "no sessions on -L $TS_SOCKET"
  # Cursor's own `agent persist` sessions live on: TMUX_TMPDIR=/tmp tmux -L cursor-agent
  agent persist list 2>/dev/null | sed 's/^/persist: /' || true
}

cmd_stop() {
  local name="${1:?name}"; check_name "$name"
  local chat; chat="$(chat_of "$name")"
  tm send-keys -t "=$name:" C-c 2>/dev/null || true; sleep 0.5
  tm send-keys -t "=$name:" C-c 2>/dev/null || true; sleep 0.5
  tm kill-session -t "=$name" 2>/dev/null || true
  ledger stop "$name" "${chat:--}" "killed"
  echo "stopped $name chat=${chat:--}"
}

case "${1:-}" in
  preflight) preflight; echo "auth ok";;
  start)  shift; cmd_start "$@";;
  send)   shift; cmd_send "$@";;
  wait)   shift; cmd_wait "$@";;
  read)   shift; cmd_read "$@";;
  ask)    shift; cmd_ask "$@";;
  status) cmd_status;;
  stop)   shift; cmd_stop "$@";;
  *) cat >&2 <<'U'
usage: ts-session.sh preflight
       ts-session.sh start NAME [--new-chat|--chat ID] [--mode ask|plan] [--cwd DIR] [--force] [--cmd 'raw shell cmd']
       ts-session.sh send NAME 'text'          # literal + Enter, flock single-writer
       ts-session.sh wait NAME 'regex' [secs]  # 0 ok | 77 auth | 124 timeout | 6 dead
       ts-session.sh read NAME [lines]         # cleaned tail, ~tokens on stderr (TS_LEANCTX=1 to compress)
       ts-session.sh ask CHAT_ID|new 'text' [--mode ask]   # headless json; chat lock, exit 5 if busy
       ts-session.sh status | stop NAME
env: TS_SOCKET (ts-shared) TS_STATE TS_LEDGER TS_ACTOR TS_TIMEOUT
U
     exit 2;;
esac
