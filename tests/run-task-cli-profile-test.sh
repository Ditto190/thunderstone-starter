#!/usr/bin/env bash
# run-task.sh CLI-only profile + per-job ledger: with HOME switched to the
# profile home, the ledger row must still carry this run's token counts. The
# CLI writes session logs to <TMPDIR or /tmp>/cursor-agent-logs-<uid> (not
# under HOME), in the JSON form ("input_tokens":"N",...). Agent exit code is
# preserved. The auth preflight runs under the same env and exits 77 when
# logged out, before any job launch. Stub agent only; PATH/HOME/TMPDIR pinned so a real CLI and the
# real log dir cannot be reached.
set -euo pipefail
if [[ -n "${BASH_ENV:-}" || -n "${ENV:-}" ]]; then
  exec env -u BASH_ENV -u ENV bash "${BASH_SOURCE[0]}" "$@"
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="${ROOT}/scripts/run-task.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "run-task cli-profile test FAIL: $*" >&2; exit 1; }

SAFE_PATH="/usr/bin:/bin"
for d in /usr/bin /bin; do
  [[ -e "${d}/agent" ]] && fail "${d}/agent exists; SAFE_PATH would reach a real agent"
done
STUB_HOME="${TMP}/home"
STUB_BIN="${STUB_HOME}/.local/bin"
PROFILE="${TMP}/cli-home"
STUB_TMP="${TMP}/tmpdir"
LOGS="${STUB_TMP}/cursor-agent-logs-$(id -u)"
MARKER="${TMP}/agent-stub-called"
STATUSMARK="${TMP}/agent-stub-status"
mkdir -p "$STUB_BIN" "${PROFILE}/.cursor" "$LOGS"
# Stub logs where the real CLI does: TMPDIR-based dir, independent of HOME.
cat >"${STUB_BIN}/agent" <<STUB
#!/bin/bash
if [[ "\${1:-}" == status ]]; then printf 'HOME=%s\\n' "\$HOME" >>"${STATUSMARK}"; ok='{"isAuthenticated":true}'; printf '%s\\n' "\${STUB_STATUS:-\$ok}"; exit 0; fi
printf 'HOME=%s\n' "\$HOME" >>"${MARKER}"
d="\${TMPDIR:-/tmp}/cursor-agent-logs-\$(id -u)"
printf '[t] {"duration_ms":"77","retries_attempted":"0","input_tokens":"21593","output_tokens":"41","cache_read_tokens":"4352","cache_write_tokens":"0","x":"y"}\n' >"\${d}/session-new-\$\$.log"
exit 42
STUB
chmod +x "${STUB_BIN}/agent"

sandbox() {
  env -u BASH_ENV -u ENV -u CURSOR_AGENT_LOG_DIR -u TS_CLI_PROFILE \
    HOME="$STUB_HOME" PATH="${STUB_BIN}:${SAFE_PATH}" TMPDIR="$STUB_TMP" "$@"
}
# shellcheck disable=SC2016  # expand inside the sandbox shell
resolved="$(sandbox bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v agent' || true)"
[[ "$resolved" == "${STUB_BIN}/agent" ]] || fail "agent resolves to '${resolved}', not the stub"

ops="${TMP}/ops"
mkdir -p "${ops}/state/pr-autopipeline"
printf '| 2000-01-01 | cursor | done |\n' >"${ops}/state/cloud-agent-ledger.md"
BRIEF="${TMP}/brief.md"
printf 'dummy brief\n' >"$BRIEF"
# Older log in the same dir must never be attributed.
printf '{"input_tokens":"901","output_tokens":"902","cache_read_tokens":"903","cache_write_tokens":"904"}\n' >"${LOGS}/session-old.log"
touch -d '2000-01-01 00:00:00' "${LOGS}/session-old.log"
LEDGER="${TMP}/ledger.tsv"
printf 'header\n' >"$LEDGER"

run_stub() {
  rm -f "$MARKER" "$STATUSMARK" "${LOGS}"/session-new-*.log
  set +e
  out="$(sandbox THUNDERSTONE_OPERATIONAL_ROOT="$ops" TS_LEDGER="$LEDGER" TS_MODEL=composer-2.5 \
    TS_JOB_ID=cli-profile-job "$@" bash "$RUN" "$BRIEF" 2>&1)"
  code=$?
  set -e
  [[ "$code" -eq 42 ]] || fail "expected stub exit 42, got ${code}: ${out}"
  [[ "$(wc -l <"$MARKER")" -eq 1 ]] || fail "stub not called exactly once: $(cat "$MARKER" 2>/dev/null)"
  grep -qi 'unbound variable' <<<"$out" && fail "unbound variable: ${out}"
  return 0
}
col() { awk -F'\t' -v n="$1" '{ print $n }' <<<"$row"; }

# 1) Profile on: agent HOME is the profile, tokens attributed from this run's log.
run_stub TS_CLI_HOME="$PROFILE"
[[ "$(cat "$MARKER")" == "HOME=${PROFILE}" ]] || fail "profile on: agent HOME wrong: $(cat "$MARKER")"
[[ "$(cat "$STATUSMARK")" == "HOME=${PROFILE}" ]] || fail "profile on: preflight not under profile: $(cat "$STATUSMARK")"
row="$(tail -n 1 "$LEDGER")"
[[ "$(wc -l <"$LEDGER")" -eq 2 ]] || fail "profile on: expected 1 row: $(cat "$LEDGER")"
[[ "$(col 8)" == "42" ]] || fail "profile on: exit column wrong: ${row}"
[[ "$(col 10)|$(col 11)|$(col 12)|$(col 13)|$(col 14)" == "77|21593|41|4352|0" ]] || fail "profile on: tokens not attributed: ${row}"
[[ "$(col 17)" == "${LOGS}/session-new-"*.log ]] || fail "profile on: source log wrong: ${row}"

# 2) Profile off: same attribution with the stub HOME.
run_stub TS_CLI_PROFILE=0 TS_CLI_HOME="$PROFILE"
[[ "$(cat "$MARKER")" == "HOME=${STUB_HOME}" ]] || fail "profile off: agent HOME wrong: $(cat "$MARKER")"
row="$(tail -n 1 "$LEDGER")"
[[ "$(col 10)|$(col 11)|$(col 12)|$(col 13)|$(col 14)" == "77|21593|41|4352|0" ]] || fail "profile off: tokens not attributed: ${row}"

# 3) Missing profile dir: empty env array under set -u, still attributed.
run_stub TS_CLI_HOME="${TMP}/missing-profile"
[[ "$(cat "$MARKER")" == "HOME=${STUB_HOME}" ]] || fail "missing dir: agent HOME wrong: $(cat "$MARKER")"
row="$(tail -n 1 "$LEDGER")"
[[ "$(col 11)" == "21593" ]] || fail "missing dir: tokens not attributed: ${row}"
[[ "$(wc -l <"$LEDGER")" -eq 4 ]] || fail "expected 3 rows total: $(cat "$LEDGER")"

# 4) Auth preflight fails (profile on and off) -> exit 77, no job launch, no row.
for extra in "TS_CLI_HOME=${PROFILE}" "TS_CLI_PROFILE=0"; do
  rm -f "$MARKER" "$STATUSMARK"
  set +e
  out="$(sandbox THUNDERSTONE_OPERATIONAL_ROOT="$ops" TS_LEDGER="$LEDGER" TS_MODEL=composer-2.5 \
    STUB_STATUS='{"isAuthenticated":false}' "$extra" bash "$RUN" "$BRIEF" 2>&1)"
  code=$?
  set -e
  [[ "$code" -eq 77 ]] || fail "auth missing (${extra}): expected 77, got ${code}: ${out}"
  [[ -s "$STATUSMARK" ]] || fail "auth missing (${extra}): preflight not run"
  [[ ! -e "$MARKER" ]] || fail "auth missing (${extra}): job launched: $(cat "$MARKER")"
  grep -qF 'AUTH_MISSING' <<<"$out" || fail "auth missing (${extra}): no message: ${out}"
done
[[ "$(wc -l <"$LEDGER")" -eq 4 ]] || fail "auth missing: ledger row appended: $(cat "$LEDGER")"

echo "run-task cli-profile tests passed."
