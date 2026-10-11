#!/usr/bin/env bash
# Thunderstone health check. Event-triggered and non-blocking; there is no schedule and no day/time logic.
# Read-only apart from its own log, state and fail artifact. Never sends a model prompt; never spends Cursor credits.
#
# Modes:
#   health.sh                    foreground run (always runs). Silent + exit 0 when green.
#                                On failure: writes artifacts/HEALTH-FAIL-<ts>.md, prints <=5 lines, exits non-zero.
#   health.sh --bg               event entry point (Cursor sessionStart hook, or a bot's first work turn).
#                                Detaches immediately (setsid/nohup), returns well under 1s with exit 0, prints nothing.
#                                The detached worker runs the checks and writes state/health-last.json (+ the log).
#   health.sh --bg --force       as --bg but ignores the once-per-session / min-interval guard.
#   health.sh --scan-agent-output  reads text on stdin; if it shows a Cursor usage-limit error, creates the flag file.
#
# Once-per-session / min-interval guard (--bg only): skip when a marker for the same session id exists
# (state/sessions/<id>.marker), or the last GREEN run is younger than HEALTH_MIN_INTERVAL_MIN (default 30), or a
# worker is already running. Session id: HEALTH_SESSION_ID, else session_id/conversation_id from the hook JSON on stdin.
#
# Usage-limit flag: state/cursor-usage-limit is created when `agent` output shows a usage-limit error and cleared
# when a later `agent status` check passes. NOTE: `agent status` cannot see a limit that only appears on a real run,
# so a clear means "login ok and no limit wording", not proof the limit has reset.
#
# Env overrides (for tests; defaults are the real paths):
#   HEALTH_FORCE_FAIL=1     inject a failing check
#   HEALTH_SKIP=a,b         skip checks: resume,doctor,git,gh,agent,disk,mem
#   HEALTH_LOG_DIR, HEALTH_ARTIFACT_DIR, HEALTH_STATE_DIR, HEALTH_STARTER, HEALTH_MODME, HEALTH_AGENT_BIN
#   HEALTH_TIMEOUT=seconds  per external call (default 20)
#   HEALTH_MIN_INTERVAL_MIN=minutes  min age of the last green run before --bg reruns (default 30)
#   HEALTH_SESSION_ID       session id for the guard marker
WORKSPACE="${WORKSPACE_ROOT:-/workspace}"
set -uo pipefail
export TZ="Australia/Sydney"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
STARTER="${HEALTH_STARTER:-$WORKSPACE/thunderstone-starter}"
MODME="${HEALTH_MODME:-$WORKSPACE/modme-ui-01}"
LOG_DIR="${HEALTH_LOG_DIR:-$WORKSPACE/thunderstone/reports}"
ART_DIR="${HEALTH_ARTIFACT_DIR:-$WORKSPACE/thunderstone/artifacts}"
STATE_DIR="${HEALTH_STATE_DIR:-$WORKSPACE/thunderstone/state}"
AGENT_BIN="${HEALTH_AGENT_BIN:-agent}"
TMO="${HEALTH_TIMEOUT:-20}"
MIN_MIN="${HEALTH_MIN_INTERVAL_MIN:-30}"
SKIP=",${HEALTH_SKIP:-},"
FLAG="$STATE_DIR/cursor-usage-limit"
LIMIT_RE='usage limit|limit reached|out of usage|quota|hit your .*limit'

mode="fg"; force=0; sid="${HEALTH_SESSION_ID:-}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --bg) mode="bg" ;;
    --worker) mode="worker" ;;
    --force) force=1 ;;
    --session) shift; sid="${1:-}" ;;
    --scan-agent-output) mode="scan" ;;
    *) ;;
  esac
  shift
done

mkdir -p "$STATE_DIR" 2>/dev/null

if [ "$mode" = scan ]; then
  txt="$(cat)"
  if printf '%s' "$txt" | grep -qiE "$LIMIT_RE"; then : > "$FLAG"; echo "usage-limit flag set: $FLAG"; fi
  exit 0
fi

if [ "$mode" = bg ]; then
  # Session id from the hook JSON on stdin (never block: only read when stdin is not a terminal, 0.5s cap).
  if [ -z "$sid" ] && [ ! -t 0 ]; then
    payload=""; IFS= read -r -t 0.5 -d '' payload || true
    if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
      sid="$(printf '%s' "$payload" | jq -r '.session_id // .conversation_id // empty' 2>/dev/null || true)"
    fi
  fi
  sid="$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_.-' | cut -c1-64)"
  if [ "$force" -eq 0 ]; then
    if [ -n "$sid" ] && [ -f "$STATE_DIR/sessions/$sid.marker" ]; then exit 0; fi
    if [ -n "$(find "$STATE_DIR/health-last-green" -mmin "-$MIN_MIN" 2>/dev/null)" ]; then exit 0; fi
    if [ -n "$(find "$STATE_DIR/health.lock" -mmin -5 2>/dev/null)" ]; then exit 0; fi
  fi
  if [ -n "$sid" ]; then mkdir -p "$STATE_DIR/sessions"; : > "$STATE_DIR/sessions/$sid.marker"; fi
  find "$STATE_DIR/sessions" -type f -name '*.marker' -mtime +2 -delete 2>/dev/null
  mkdir -p "$LOG_DIR" 2>/dev/null
  setsid nohup bash "$SELF" --worker --session "$sid" >"$LOG_DIR/health-bg.out" 2>&1 </dev/null &
  disown 2>/dev/null || true
  exit 0
fi

day="$(date +%Y%m%d)"
ts="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR" "$ART_DIR"
[ "$mode" = worker ] && : > "$STATE_DIR/health.lock"

fails=()      # "name: detail"
warns=()
notes=()      # compact ok-fields for the log line
skipped() { case "$SKIP" in *",$1,"*) return 0 ;; esac; return 1; }
fail() { fails+=("$1: $2"); }
warn() { warns+=("$1: $2"); }
run() { timeout "$TMO" "$@" 2>&1; }
arr_json() { if [ "$#" -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -R . | jq -s -c .; fi; }

write_state() {   # $1=green|fail  $2=artifact path or empty
  local f="$STATE_DIR/health-last.json" tmp="$STATE_DIR/health-last.json.$$"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg status "$1" --arg ts "$ts" --arg mode "$mode" --arg sid "$sid" --arg art "$2" \
      --argjson epoch "$(date +%s)" \
      --argjson fails "$(arr_json "${fails[@]+"${fails[@]}"}")" \
      --argjson warns "$(arr_json "${warns[@]+"${warns[@]}"}")" \
      --argjson notes "$(arr_json "${notes[@]+"${notes[@]}"}")" \
      '{status:$status,ts:$ts,epoch:$epoch,mode:$mode,session_id:$sid,artifact:$art,fails:$fails,warns:$warns,notes:$notes}' > "$tmp"
  else
    printf '{"status":"%s","ts":"%s","artifact":"%s"}\n' "$1" "$ts" "$2" > "$tmp"
  fi
  mv -f "$tmp" "$f"
}

if [ "${HEALTH_FORCE_FAIL:-0}" = "1" ]; then fail "forced" "HEALTH_FORCE_FAIL=1 (test injection)"; fi

# 1. resume.sh + doctor.sh in the starter (resume.sh only ensures the tmux session exists)
if ! skipped resume; then
  if out="$(cd "$STARTER" 2>/dev/null && run bash scripts/resume.sh)"; then notes+=("resume=ok")
  else fail "resume.sh" "non-zero ($(printf '%s' "$out" | tail -n1 | cut -c1-80))"; fi
fi
if ! skipped doctor; then
  if out="$(cd "$STARTER" 2>/dev/null && run bash scripts/doctor.sh)"; then notes+=("doctor=ok")
  else fail "doctor.sh" "$(printf '%s' "$out" | grep -E '^MISSING' | tr '\n' ' ' | cut -c1-100)"; fi
fi

# 2. git status --short counts (informational; failure only if git itself fails)
if ! skipped git; then
  for pair in "starter:$STARTER" "modme:$MODME"; do
    label="${pair%%:*}"; dir="${pair#*:}"
    if n="$(cd "$dir" 2>/dev/null && timeout "$TMO" git status --short 2>/dev/null | wc -l)"; then
      notes+=("git_${label}=${n}")
    else fail "git status ($label)" "cannot read $dir"; fi
  done
fi

# 3. GitHub CLI auth (wrapped: gh can hang)
if ! skipped gh; then
  if run gh auth status >/dev/null; then notes+=("gh=ok"); else fail "gh auth" "not logged in or timed out"; fi
fi

# 4. Cursor CLI login + usage-limit condition. `agent status` sends no model prompt, so no credits are spent.
#    A usage limit only surfaces on a real run, so we also honour the flag file (created here when limit wording
#    appears, or by `--scan-agent-output` from whoever hit it) and clear it when a later status check passes.
#    Reported as a condition, never a crash.
if ! skipped agent; then
  if ! command -v "$AGENT_BIN" >/dev/null; then fail "agent" "CLI not installed"
  else
    out="$(run "$AGENT_BIN" status)"; rc=$?
    if printf '%s' "$out" | grep -qiE "$LIMIT_RE"; then
      : > "$FLAG"
      warn "cursor" "usage limit reported by agent status"; notes+=("cursor=LIMIT")
    elif [ "$rc" -ne 0 ] || ! printf '%s' "$out" | grep -qi 'logged in'; then
      fail "agent status" "not logged in or timed out (rc=$rc)"
    else
      notes+=("cursor=login-ok")
      if [ -f "$FLAG" ]; then rm -f "$FLAG"; notes+=("cursor_flag=cleared"); fi
    fi
  fi
  if [ -f "$FLAG" ] && [[ " ${notes[*]:-} " != *" cursor=LIMIT "* ]]; then warn "cursor" "usage-limit flag present ($(date -r "$FLAG" +%Y%m%d))"; notes+=("cursor_flag=set"); fi
fi

# 5. Disk and memory
if ! skipped disk; then
  used="$(df -P "$WORKSPACE" 2>/dev/null | awk 'NR==2{gsub("%","",$5);print $5}')"
  if [ -z "$used" ]; then fail "disk" "df failed"
  elif [ "$used" -ge 90 ]; then fail "disk" "$WORKSPACE ${used}% used"
  else notes+=("disk=${used}%"); fi
fi
if ! skipped mem; then
  avail="$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null)"
  if [ -z "$avail" ]; then fail "mem" "cannot read /proc/meminfo"
  elif [ "$avail" -lt 300 ]; then fail "mem" "only ${avail}MB available"
  else notes+=("mem=${avail}MB"); fi
fi

if [ "${#fails[@]}" -eq 0 ]; then
  line="$(date +%H:%M:%S) GREEN ${notes[*]:-}"
  [ "${#warns[@]}" -gt 0 ] && line="$line WARN: ${warns[*]}"
  printf '%s\n' "$line" >> "$LOG_DIR/health-$day.log"
  : > "$STATE_DIR/health-last-green"
  write_state green ""
  rm -f "$STATE_DIR/health.lock"
  exit 0
fi

art="$ART_DIR/HEALTH-FAIL-$ts.md"
{
  echo "# Health check FAILED $ts (Australia/Sydney)"
  echo
  echo "## Failures"; for f in "${fails[@]}"; do echo "- $f"; done
  if [ "${#warns[@]}" -gt 0 ]; then echo; echo "## Conditions"; for w in "${warns[@]}"; do echo "- $w"; done; fi
  echo; echo "## Passing fields"; echo "${notes[*]:-none}"
  echo; echo "Read-only check; nothing was changed. Re-run: bash $WORKSPACE/thunderstone/scripts/health.sh"
} > "$art"
printf '%s\n' "$(date +%H:%M:%S) FAIL ${fails[*]}" >> "$LOG_DIR/health-$day.log"
write_state fail "$art"
rm -f "$STATE_DIR/health.lock"

echo "HEALTH FAIL ${ts}: ${#fails[@]} failing check(s)"
n=0
for f in "${fails[@]}"; do n=$((n+1)); [ "$n" -le 3 ] && echo " - $f"; done
echo "Evidence: $art"
exit 1
