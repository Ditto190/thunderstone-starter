#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPATCH="${ROOT}/.cursor/hooks/dispatch.sh"
TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

failures=0

fail() {
  echo "hooks-dispatch test FAIL: $1" >&2
  failures=1
}

assert_exact() {
  local name="$1" expected="$2" out="$3"
  if [ "$out" != "$expected" ]; then
    echo "hooks-dispatch test FAIL: $name" >&2
    echo "  expected: $expected" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

run_dispatch() {
  local dir="$1"
  shift
  (
    cd "$dir"
    env -u BASH_ENV "$@" bash "$DISPATCH"
  )
}

# malformed JSON
work="${TMP_BASE}/malformed"
mkdir -p "$work"
err="${TMP_BASE}/malformed.err"
set +e
out="$(printf 'not-json' | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state" 2>"$err")"
rc=$?
set -e
assert_exact "malformed-json" '{}' "$out"
if [ "$rc" -ne 0 ]; then fail "malformed exit ${rc}"; fi
if [ -s "$err" ]; then fail "malformed wrote stderr"; fi

# unknown event
work="${TMP_BASE}/unknown"
mkdir -p "$work"
err="${TMP_BASE}/unknown.err"
set +e
out="$(printf '%s' '{"hook_event_name":"notARealEvent"}' | run_dispatch "$work" 2>"$err")"
rc=$?
set -e
assert_exact "unknown-event" '{}' "$out"
if [ "$rc" -ne 0 ]; then fail "unknown exit ${rc}"; fi
if [ -s "$err" ]; then fail "unknown wrote stderr"; fi

# slow handler killed at budget
fix="${TMP_BASE}/slow-events"
mkdir -p "$fix"
cat >"${fix}/session-start.sh" <<'EOF'
#!/bin/sh
sleep 30
printf '%s\n' '{"additional_context":"slow"}'
EOF
chmod +x "${fix}/session-start.sh"
work="${TMP_BASE}/slow"
mkdir -p "$work"
start="$SECONDS"
set +e
out="$(printf '%s' '{"hook_event_name":"sessionStart","conversation_id":"slow1"}' | run_dispatch "$work" HOOKS_EVENTS_DIR="$fix" HOOKS_BUDGET_SEC=1)"
rc=$?
set -e
elapsed=$((SECONDS - start))
assert_exact "slow-json" '{}' "$out"
if [ "$rc" -ne 0 ]; then fail "slow exit ${rc}"; fi
if [ "$elapsed" -ge 8 ]; then fail "slow handler not killed (${elapsed}s)"; fi

# once per session
work="${TMP_BASE}/once"
mkdir -p "$work"
state="${work}/state"
payload='{"hook_event_name":"sessionStart","conversation_id":"once-1"}'
err="${TMP_BASE}/once.err"
set +e
out1="$(printf '%s' "$payload" | run_dispatch "$work" HOOKS_STATE_DIR="$state" 2>"$err")"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then fail "once first exit ${rc}"; fi
if ! printf '%s' "$out1" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{JSON.parse(s);});'; then
  fail "once first not json"
fi
if [ -s "$err" ]; then fail "once first wrote stderr"; fi
if [ ! -f "${state}/seen/sessionStart-once-1" ]; then fail "once marker missing"; fi
out2="$(printf '%s' "$payload" | run_dispatch "$work" HOOKS_STATE_DIR="$state")"
assert_exact "once-second" '{}' "$out2"

# tool failure append + redact
work="${TMP_BASE}/fail"
mkdir -p "$work"
state="${work}/state"
secret='Bearer short-token token=abc'
printf '%s' "{\"hook_event_name\":\"postToolUseFailure\",\"tool_name\":\"Shell\",\"error_message\":\"boom ${secret}\"}" \
  | run_dispatch "$work" HOOKS_STATE_DIR="$state" >/dev/null
line="$(cat "${state}/tool-failures.jsonl")"
if ! printf '%s' "$line" | grep -q '"tool":"Shell"'; then fail "tool name missing"; fi
if printf '%s' "$line" | grep -q 'short-token'; then fail "token not redacted"; fi
if ! printf '%s' "$line" | grep -q 'Bearer \[REDACTED\]'; then fail "bearer redact missing"; fi
out="$(printf '%s' '{"hook_event_name":"postToolUseFailure","tool_name":"Shell","error_message":"x"}' | run_dispatch "$work" HOOKS_STATE_DIR="$state")"
assert_exact "tool-stdout" '{}' "$out"

# report-edit only under reports/
work="${TMP_BASE}/edit"
mkdir -p "$work/reports" "$work/src" "$work/state"
printf '%s' '{"hook_event_name":"afterFileEdit","file_path":"reports/note.md"}' \
  | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state" >/dev/null
printf '%s' '{"hook_event_name":"afterFileEdit","file_path":"reports/note.md"}' \
  | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state" >/dev/null
printf '%s' '{"hook_event_name":"afterFileEdit","file_path":"src/note.js"}' \
  | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state" >/dev/null
printf '%s' '{"hook_event_name":"afterFileEdit","file_path":"workspace/reports/other.md"}' \
  | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state" >/dev/null
index="$(cat "${work}/state/reports-index.md")"
if ! printf '%s\n' "$index" | grep -qxF -- '- reports/note.md'; then fail "report index missing"; fi
if ! printf '%s\n' "$index" | grep -qxF -- '- workspace/reports/other.md'; then fail "workspace report missing"; fi
if printf '%s\n' "$index" | grep -q 'src/note.js'; then fail "non-report indexed"; fi
count="$(printf '%s\n' "$index" | grep -cF -- '- reports/note.md' || true)"
if [ "$count" -ne 1 ]; then fail "report path not deduped (${count})"; fi

# stop stub only with active-brief
work="${TMP_BASE}/stop-none"
mkdir -p "$work"
out="$(printf '%s' '{"hook_event_name":"stop","conversation_id":"stop-none"}' | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state")"
assert_exact "stop-absent" '{}' "$out"
if [ -d "${work}/state/receipts" ]; then fail "stop wrote receipt without brief"; fi

work="${TMP_BASE}/stop-yes"
mkdir -p "${work}/.state"
printf 'brief\n' >"${work}/.state/active-brief"
out="$(printf '%s' '{"hook_event_name":"stop","conversation_id":"stop-yes"}' | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state")"
assert_exact "stop-present" '{}' "$out"
if [ ! -f "${work}/state/receipts/stop-yes.stub" ]; then fail "stop receipt missing"; fi
out="$(printf '%s' '{"hook_event_name":"stop","conversation_id":"stop-yes"}' | run_dispatch "$work" HOOKS_STATE_DIR="${work}/state")"
assert_exact "stop-second" '{}' "$out"
n="$(find "${work}/state/receipts" -type f | wc -l | tr -d ' ')"
if [ "$n" -ne 1 ]; then fail "stop receipt not once (${n})"; fi

# bridge drift note
ops="${TMP_BASE}/ops"
repo="${TMP_BASE}/drift-repo"
mkdir -p "${ops}/bridge/src" "${repo}/workspace/bridge/src" "${repo}/state"
printf 'a\n' >"${ops}/bridge/src/a.js"
printf 'b\n' >"${repo}/workspace/bridge/src/a.js"
payload='{"hook_event_name":"sessionStart","conversation_id":"drift-1"}'
out="$(printf '%s' "$payload" | run_dispatch "$repo" HOOKS_STATE_DIR="${repo}/state" THUNDERSTONE_ROOT="$ops")"
if ! printf '%s' "$out" | grep -q 'DRIFT bridge: 1 files'; then
  fail "drift note missing: ${out}"
fi
err="${TMP_BASE}/drift.err"
set +e
out2="$(printf '%s' "$payload" | run_dispatch "$repo" HOOKS_STATE_DIR="${repo}/state" THUNDERSTONE_ROOT="$ops" 2>"$err")"
rc=$?
set -e
assert_exact "drift-second" '{}' "$out2"
if [ "$rc" -ne 0 ]; then fail "drift second exit ${rc}"; fi
if [ -s "$err" ]; then fail "green drift wrote stderr"; fi

if [ "$failures" -ne 0 ]; then
  echo "hooks-dispatch tests failed" >&2
  exit 1
fi
echo "hooks-dispatch fixture tests passed."
