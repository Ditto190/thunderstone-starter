#!/usr/bin/env bash
# Plain-bash tests for health.sh (bats is not installed). Uses temp dirs; touches no real state; never runs the real agent.
# Run: bash <workspace>/thunderstone/scripts/tests/health-test.sh
set -uo pipefail
HS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/health.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HEALTH_LOG_DIR="$T/logs" HEALTH_ARTIFACT_DIR="$T/art" HEALTH_STATE_DIR="$T/state"
export HEALTH_SKIP="resume,doctor,gh,agent,git"   # keep tests hermetic; disk/mem still real
cnt() { find "$1" -maxdepth 1 -type f -name "${2:-*}" 2>/dev/null | wc -l; }
pass=0; failn=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok   - $1"; else failn=$((failn+1)); echo "FAIL - $1 (want '$3' got '$2')"; fi; }
reset() { rm -rf "${T:?}/art" "${T:?}/logs" "${T:?}/state"; }
# wait (max ~20s) for the detached worker to finish: it writes health-last.json last
waitjson() { local i=0; while [ ! -s "$T/state/health-last.json" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i+1)); done; sleep 0.3; }
loglines() { cat "$T"/logs/health-2*.log 2>/dev/null | wc -l; }

# 1. No weekday/time logic: the script holds none, and a green run is silent whatever the day
check "no weekday guard in health.sh" "$(grep -cE 'date \+%u|HEALTH_FORCE_DAY|weekend' "$HS")" 0
check "no cron/timer wiring in health.sh" "$(grep -ciE 'crontab|systemd|systemctl|at -f' "$HS")" 0
reset
out="$(HEALTH_FORCE_DAY=6 HEALTH_FORCE_FAIL=1 bash "$HS" 2>&1)"; rc=$?
check "formerly-weekend run now executes (forced fail exits non-zero)" "$([ "$rc" -ne 0 ] && echo yes)" yes

# 2. Green run: silent, exit 0, one log line, no fail artifact
reset
out="$(bash "$HS" 2>&1)"; rc=$?
check "green exits 0" "$rc" 0
check "green is silent" "$out" ""
check "green appends one log line" "$(loglines)" 1
check "green log says GREEN" "$(grep -c GREEN "$T"/logs/health-2*.log)" 1
check "green writes no fail artifact" "$(cnt "$T/art")" 0
check "green writes health-last.json status=green" "$(jq -r .status "$T/state/health-last.json")" green

# 3. Forced fail: non-zero, <=5 lines, artifact written, state says fail
reset
out="$(HEALTH_FORCE_FAIL=1 bash "$HS" 2>&1)"; rc=$?
check "forced fail exits non-zero" "$([ "$rc" -ne 0 ] && echo yes)" yes
check "forced fail prints <=5 lines" "$([ "$(printf '%s\n' "$out" | wc -l)" -le 5 ] && echo yes)" yes
check "forced fail writes HEALTH-FAIL artifact" "$(cnt "$T/art" "HEALTH-FAIL-*.md")" 1
check "fail artifact names the cause" "$(grep -c 'HEALTH_FORCE_FAIL' "$T"/art/HEALTH-FAIL-*.md)" 1
check "fail logged" "$(grep -c FAIL "$T"/logs/health-2*.log)" 1
check "health-last.json status=fail" "$(jq -r .status "$T/state/health-last.json")" fail

# 4. Real failure path: unreadable starter dir makes the git check fail
reset
out="$(HEALTH_SKIP="resume,doctor,gh,agent" HEALTH_STARTER="$T/nope" HEALTH_MODME="$T/nope" bash "$HS" 2>&1)"; rc=$?
check "missing repo dir fails" "$([ "$rc" -ne 0 ] && echo yes)" yes

# 5. Idempotent / read-only: two green foreground runs only append log lines
reset
bash "$HS" >/dev/null 2>&1; bash "$HS" >/dev/null 2>&1
check "two green runs -> two log lines, no artifacts" "$(loglines)/$(cnt "$T/art")" "2/0"

# 6. --bg: returns <1s with exit 0 and no output, then the worker writes state + log silently
reset
s=$(date +%s.%N); out="$(bash "$HS" --bg </dev/null 2>&1)"; rc=$?; e=$(date +%s.%N)
check "--bg exits 0" "$rc" 0
check "--bg prints nothing" "$out" ""
check "--bg returns in <1s" "$(awk -v s="$s" -v e="$e" 'BEGIN{print (e-s<1)?"yes":"no"}')" yes
waitjson
check "--bg worker writes health-last.json green" "$(jq -r .status "$T/state/health-last.json")" green
check "--bg worker logs one GREEN line" "$(loglines)" 1
check "--bg green writes no fail artifact" "$(cnt "$T/art")" 0
check "--bg green keeps the bg output file empty" "$(wc -c < "$T/logs/health-bg.out" | tr -d ' ')" 0

# 7. --bg slow checks do not block the caller (hung resume.sh stub in a fake starter)
reset
mkdir -p "$T/starter/scripts"; printf '#!/usr/bin/env bash\nsleep 30\n' > "$T/starter/scripts/resume.sh"
s=$(date +%s.%N); HEALTH_STARTER="$T/starter" HEALTH_SKIP="doctor,gh,agent,git" HEALTH_TIMEOUT=2 bash "$HS" --bg </dev/null; rc=$?; e=$(date +%s.%N)
check "--bg returns <1s even when a check hangs" "$(awk -v s="$s" -v e="$e" 'BEGIN{print (e-s<1)?"yes":"no"}')/$rc" "yes/0"
waitjson
check "--bg hung check ends as fail within timeout" "$(jq -r .status "$T/state/health-last.json")" fail
check "--bg failure writes HEALTH-FAIL artifact" "$(cnt "$T/art" "HEALTH-FAIL-*.md")" 1
rm -rf "${T:?}/starter"

# 8. Guard: same session id does not rerun; min interval blocks other sessions; new session after interval reruns
reset
HEALTH_SESSION_ID=s1 bash "$HS" --bg </dev/null; waitjson
check "first --bg ran once" "$(loglines)" 1
HEALTH_SESSION_ID=s1 bash "$HS" --bg </dev/null; sleep 1.5
check "same session id does not rerun" "$(loglines)" 1
HEALTH_SESSION_ID=s2 bash "$HS" --bg </dev/null; sleep 1.5
check "new session within 30 min of a green run does not rerun" "$(loglines)" 1
check "marker exists for s1" "$([ -f "$T/state/sessions/s1.marker" ] && echo yes)" yes
HEALTH_SESSION_ID=s3 HEALTH_MIN_INTERVAL_MIN=0 bash "$HS" --bg </dev/null; sleep 2
check "new session with interval elapsed reruns" "$(loglines)" 2
HEALTH_SESSION_ID=s3 HEALTH_MIN_INTERVAL_MIN=0 bash "$HS" --bg --force </dev/null; sleep 2
check "--force bypasses the guard" "$(loglines)" 3
# session id read from hook JSON on stdin
reset
printf '{"session_id":"hookjson1","hook_event_name":"sessionStart"}' | bash "$HS" --bg; waitjson
check "session id taken from hook JSON on stdin" "$([ -f "$T/state/sessions/hookjson1.marker" ] && echo yes)" yes

# 9. Usage-limit flag: created from agent output, cleared by a later passing check
reset
mkdir -p "$T/bin"
printf '#!/usr/bin/env bash\necho "Error: you have hit your usage limit"\nexit 1\n' > "$T/bin/agent-limit"
printf '#!/usr/bin/env bash\necho "Logged in as test"\nexit 0\n' > "$T/bin/agent-ok"
chmod +x "$T/bin/agent-limit" "$T/bin/agent-ok"
HEALTH_SKIP="resume,doctor,gh,git" HEALTH_AGENT_BIN="$T/bin/agent-limit" bash "$HS" >/dev/null 2>&1; rc=$?
check "usage limit is a condition, not a failure (exit 0)" "$rc" 0
check "usage-limit flag auto-created" "$([ -f "$T/state/cursor-usage-limit" ] && echo yes)" yes
check "usage limit recorded as warning in state" "$(jq -r '.warns|length' "$T/state/health-last.json")" 1
HEALTH_SKIP="resume,doctor,gh,git" HEALTH_AGENT_BIN="$T/bin/agent-ok" bash "$HS" >/dev/null 2>&1; rc=$?
check "later passing check exits 0" "$rc" 0
check "usage-limit flag cleared by passing check" "$([ -f "$T/state/cursor-usage-limit" ] && echo still || echo gone)" gone
printf 'something\nQuota exceeded: usage limit reached\n' | bash "$HS" --scan-agent-output >/dev/null
check "--scan-agent-output creates the flag" "$([ -f "$T/state/cursor-usage-limit" ] && echo yes)" yes
rm -f "$T/state/cursor-usage-limit"
printf 'all fine\n' | bash "$HS" --scan-agent-output >/dev/null
check "--scan-agent-output ignores normal output" "$([ -f "$T/state/cursor-usage-limit" ] && echo yes || echo no)" no
rm -rf "${T:?}/bin"

echo "passed=$pass failed=$failn"
[ "$failn" -eq 0 ]
