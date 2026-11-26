#!/usr/bin/env bash
# run-task.sh per-job ledger hook: appends one TSV row when the ledger file
# exists, is a no-op when it is missing, and always preserves the agent exit
# code (even when the append fails). Stub agent only; PATH/HOME pinned like the
# other run-task tests so a real CLI cannot be reached. Token columns come only
# from a session log written during the run (older logs are never attributed).
set -euo pipefail
if [[ -n "${BASH_ENV:-}" || -n "${ENV:-}" ]]; then
  exec env -u BASH_ENV -u ENV bash "${BASH_SOURCE[0]}" "$@"
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="${ROOT}/scripts/run-task.sh"
TMP="$(mktemp -d)"
trap 'chmod -R u+w "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT
fail() { echo "run-task ledger test FAIL: $*" >&2; exit 1; }

SAFE_PATH="/usr/bin:/bin"
for d in /usr/bin /bin; do
  [[ -e "${d}/agent" ]] && fail "${d}/agent exists; SAFE_PATH would reach a real agent"
done
STUB_HOME="${TMP}/home"
STUB_BIN="${STUB_HOME}/.local/bin"
MARKER="${TMP}/agent-stub-called"
LOGS="${TMP}/agent-logs"
mkdir -p "$STUB_BIN" "$LOGS"
cat >"${STUB_BIN}/agent" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"${MARKER}"
if [[ -z "\${STUB_NO_LOG:-}" ]]; then
  printf 'usage input_tokens=11, output_tokens=22, cache_read_tokens=33, cache_write_tokens=44, duration_ms=55\n' >"${LOGS}/session-new-\$\$.log"
fi
exit 42
STUB
chmod +x "${STUB_BIN}/agent"

sandbox() {
  env -u BASH_ENV -u ENV HOME="$STUB_HOME" PATH="${STUB_BIN}:${SAFE_PATH}" "$@"
}

ops="${TMP}/ops"
mkdir -p "${ops}/state/pr-autopipeline"
printf '| 2000-01-01 | cursor | done |\n' >"${ops}/state/cloud-agent-ledger.md"
BRIEF="${TMP}/brief.md"
printf 'dummy brief\n' >"$BRIEF"

# Older session log with other counts; must never be attributed to a new job.
printf 'usage input_tokens=901, output_tokens=902, cache_read_tokens=903, cache_write_tokens=904, duration_ms=905\n' >"${LOGS}/session-old.log"
touch -d '2000-01-01 00:00:00' "${LOGS}/session-old.log"

# run_stub <ledger-path> [env...] : runs run-task.sh against the stub, asserts exit 42.
# TS_MODEL is pinned so an exported caller value cannot break the model column check.
run_stub() {
  local ledger="$1"; shift
  rm -f "$MARKER" "${LOGS}"/session-new-*.log
  set +e
  out="$(sandbox THUNDERSTONE_OPERATIONAL_ROOT="$ops" TS_LEDGER="$ledger" TS_MODEL=composer-2.5 "$@" \
    CURSOR_AGENT_LOG_DIR="$LOGS" TS_JOB_ID=ledger-test-job \
    bash "$RUN" "$BRIEF" 2>&1)"
  code=$?
  set -e
  [[ "$code" -eq 42 ]] || fail "expected stub exit 42, got ${code}: ${out}"
  [[ -s "$MARKER" ]] || fail "stub marker missing; something other than the stub ran"
  [[ "$(wc -l <"$MARKER")" -eq 1 ]] || fail "stub called more than once: $(cat "$MARKER")"
}

# 1) Ledger exists -> exactly one row appended, with job id and exit code.
LEDGER="${TMP}/ledger.tsv"
printf 'header\n' >"$LEDGER"
run_stub "$LEDGER"
[[ "$(wc -l <"$LEDGER")" -eq 2 ]] || fail "exists: expected 1 appended row: $(cat "$LEDGER")"
row="$(tail -n 1 "$LEDGER")"
# Tab is IFS whitespace (empty fields collapse in read -a), so split with awk.
col() { awk -F'\t' -v n="$1" '{ print $n }' <<<"$row"; }
[[ "$(awk -F'\t' '{ print NF }' <<<"$row")" -eq 18 ]] || fail "exists: expected 18 columns: ${row}"
[[ "$(col 2)" == "ledger-test-job" ]] || fail "exists: job id column wrong: ${row}"
[[ "$(col 4)" == "cursor-agent" ]] || fail "exists: cli column wrong: ${row}"
[[ "$(col 5)" == "composer-2.5" ]] || fail "exists: model column wrong: ${row}"
[[ "$(col 8)" == "42" ]] || fail "exists: exit code column wrong: ${row}"
[[ "$(col 10)|$(col 11)|$(col 12)|$(col 13)|$(col 14)" == "55|11|22|33|44" ]] || fail "exists: token columns not from this run's log: ${row}"

# 1b) No session log written this run -> token columns blank (old log ignored).
run_stub "$LEDGER" STUB_NO_LOG=1
row="$(tail -n 1 "$LEDGER")"
[[ "$(wc -l <"$LEDGER")" -eq 3 ]] || fail "no-log: expected 2 appended rows: $(cat "$LEDGER")"
[[ "$(col 8)" == "42" ]] || fail "no-log: exit code column wrong: ${row}"
[[ -z "$(col 10)$(col 11)$(col 12)$(col 13)$(col 14)$(col 17)" ]] || fail "no-log: stale log attributed: ${row}"

# 2) Ledger missing -> no-op (file not created), exit code preserved.
MISSING="${TMP}/missing/ledger.tsv"
run_stub "$MISSING"
[[ ! -e "$MISSING" ]] || fail "missing: ledger was created"

# 3) Append fails (read-only ledger) -> exit code still 42, warning emitted.
if [[ "$(id -u)" -ne 0 ]]; then
  RO="${TMP}/ro-ledger.tsv"
  printf 'header\n' >"$RO"
  chmod 0444 "$RO"
  run_stub "$RO"
  [[ "$(wc -l <"$RO")" -eq 1 ]] || fail "read-only: ledger was modified"
  grep -qF 'warn: ledger append failed' <<<"$out" || fail "read-only: no warning: ${out}"
else
  echo "skip: read-only ledger case (running as root)"
fi

echo "run-task ledger tests passed."
