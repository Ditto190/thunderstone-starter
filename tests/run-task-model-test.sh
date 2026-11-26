#!/usr/bin/env bash
# run-task.sh must pass --model composer-2.5 by default, or --model "$TS_MODEL"
# when that env var is set. CLI-only profile: TS_CLI_PROFILE=0 and a missing
# profile dir must launch exactly as before (same args, same env, no unbound
# variable under set -u); an existing profile switches HOME/CURSOR_*/XDG_* for
# the agent only. Stub agent only; PATH/HOME pinned like the other run-task
# tests so a real CLI cannot be reached.
set -euo pipefail
if [[ -n "${BASH_ENV:-}" || -n "${ENV:-}" ]]; then
  exec env -u BASH_ENV -u ENV bash "${BASH_SOURCE[0]}" "$@"
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="${ROOT}/scripts/run-task.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "run-task model test FAIL: $*" >&2; exit 1; }

SAFE_PATH="/usr/bin:/bin"
for d in /usr/bin /bin; do
  [[ -e "${d}/agent" ]] && fail "${d}/agent exists; SAFE_PATH would reach a real agent"
done
STUB_HOME="${TMP}/home"
STUB_BIN="${STUB_HOME}/.local/bin"
MARKER="${TMP}/agent-stub-called"
ENVMARK="${TMP}/agent-stub-env"
mkdir -p "$STUB_BIN"
cat >"${STUB_BIN}/agent" <<STUB
#!/bin/bash
if [[ "\${1:-}" == status ]]; then ok='{"isAuthenticated":true}'; printf '%s\\n' "\${STUB_STATUS:-\$ok}"; exit 0; fi
printf '%s\n' "\$*" >>"${MARKER}"
for v in HOME CURSOR_CONFIG_DIR CURSOR_DATA_DIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME; do
  printf '%s=%s\n' "\$v" "\${!v-<unset>}"
done >"${ENVMARK}"
exit 42
STUB
chmod +x "${STUB_BIN}/agent"

# Caller XDG value must pass through untouched when the profile is off.
# TS_CLI_HOME defaults to a missing dir so a real profile on the VM is never used.
sandbox() {
  env -u BASH_ENV -u ENV -u CURSOR_CONFIG_DIR -u CURSOR_DATA_DIR -u XDG_DATA_HOME \
    -u XDG_STATE_HOME -u XDG_CACHE_HOME -u TS_CLI_PROFILE \
    HOME="$STUB_HOME" PATH="${STUB_BIN}:${SAFE_PATH}" XDG_CONFIG_HOME=/caller/xdg \
    TS_CLI_HOME="${TMP}/no-profile" "$@"
}
# shellcheck disable=SC2016  # expand inside the sandbox shell
resolved="$(sandbox bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v agent' || true)"
[[ "$resolved" == "${STUB_BIN}/agent" ]] || fail "agent resolves to '${resolved}', not the stub"

ops="${TMP}/ops"
mkdir -p "${ops}/state"
printf '| 2000-01-01 | cursor | done |\n' >"${ops}/state/cloud-agent-ledger.md"
BRIEF="${TMP}/brief.md"
printf 'dummy brief\n' >"$BRIEF"

run_stub() {
  rm -f "$MARKER" "$ENVMARK"
  set +e
  out="$(sandbox THUNDERSTONE_OPERATIONAL_ROOT="$ops" "$@" bash "$RUN" "$BRIEF" 2>&1)"
  code=$?
  set -e
  [[ "$code" -eq 42 ]] || fail "expected stub exit 42, got ${code}: ${out}"
  [[ -s "$MARKER" ]] || fail "stub marker missing; something other than the stub ran"
  [[ "$(wc -l <"$MARKER")" -eq 1 ]] || fail "stub called more than once: $(cat "$MARKER")"
  grep -qi 'unbound variable' <<<"$out" && fail "unbound variable: ${out}"
  return 0
}

# Default: TS_MODEL unset -> --model composer-2.5
run_stub env -u TS_MODEL
grep -qF -- '--model composer-2.5' "$MARKER" || fail "default: missing --model composer-2.5: $(cat "$MARKER")"

# Override: TS_MODEL wins; default model string must not be passed
run_stub env TS_MODEL=test-model-override
grep -qF -- '--model test-model-override' "$MARKER" || fail "override: missing --model test-model-override: $(cat "$MARKER")"
grep -qF -- '--model composer-2.5' "$MARKER" && fail "override: default model still passed: $(cat "$MARKER")"

# --- CLI-only profile -------------------------------------------------------
PROFILE="${TMP}/cli-home"
mkdir -p "${PROFILE}/.cursor"
OLD_ENV="HOME=${STUB_HOME}
CURSOR_CONFIG_DIR=<unset>
CURSOR_DATA_DIR=<unset>
XDG_CONFIG_HOME=/caller/xdg
XDG_DATA_HOME=<unset>
XDG_STATE_HOME=<unset>
XDG_CACHE_HOME=<unset>"

# Baseline: profile dir missing -> empty _ts_cli_env, pre-profile launch.
run_stub env -u TS_MODEL
base_args="$(cat "$MARKER")"
[[ "$(cat "$ENVMARK")" == "$OLD_ENV" ]] || fail "missing-dir: env changed: $(cat "$ENVMARK")"

# TS_CLI_PROFILE=0 with a real profile dir -> identical args and env to baseline.
run_stub env -u TS_MODEL TS_CLI_PROFILE=0 TS_CLI_HOME="$PROFILE"
[[ "$(cat "$MARKER")" == "$base_args" ]] || fail "profile=0: args differ: $(cat "$MARKER")"
[[ "$(cat "$ENVMARK")" == "$OLD_ENV" ]] || fail "profile=0: env changed: $(cat "$ENVMARK")"

# TS_CLI_PROFILE=0 with TS_CLI_HOME unset (default path) -> still baseline.
run_stub env -u TS_MODEL -u TS_CLI_HOME TS_CLI_PROFILE=0
[[ "$(cat "$MARKER")" == "$base_args" ]] || fail "profile=0 default home: args differ: $(cat "$MARKER")"
[[ "$(cat "$ENVMARK")" == "$OLD_ENV" ]] || fail "profile=0 default home: env changed: $(cat "$ENVMARK")"

# Profile dir exists, no .cursor inside -> treated as missing.
mkdir -p "${TMP}/bare-home"
run_stub env -u TS_MODEL TS_CLI_HOME="${TMP}/bare-home"
[[ "$(cat "$ENVMARK")" == "$OLD_ENV" ]] || fail "no .cursor: env changed: $(cat "$ENVMARK")"

# Profile on -> same args, agent sees the profile HOME/CURSOR_*/XDG_*.
run_stub env -u TS_MODEL TS_CLI_HOME="$PROFILE"
[[ "$(cat "$MARKER")" == "$base_args" ]] || fail "profile on: args differ: $(cat "$MARKER")"
NEW_ENV="HOME=${PROFILE}
CURSOR_CONFIG_DIR=${PROFILE}/.cursor
CURSOR_DATA_DIR=${PROFILE}/.cursor
XDG_CONFIG_HOME=${PROFILE}/.config
XDG_DATA_HOME=${PROFILE}/.local/share
XDG_STATE_HOME=${PROFILE}/.local/state
XDG_CACHE_HOME=${PROFILE}/.cache"
[[ "$(cat "$ENVMARK")" == "$NEW_ENV" ]] || fail "profile on: env wrong: $(cat "$ENVMARK")"

# Default profile home (TS_CLI_HOME unset) is the ops root's sibling
# token-optimizer/state/cursor-cli-home; TS_CLI_PROFILE=0 still wins.
DEF="${TMP}/token-optimizer/state/cursor-cli-home"
mkdir -p "${DEF}/.cursor"
run_stub env -u TS_MODEL -u TS_CLI_HOME TS_CLI_PROFILE=0
[[ "$(cat "$ENVMARK")" == "$OLD_ENV" ]] || fail "default home, profile=0: env changed: $(cat "$ENVMARK")"
run_stub env -u TS_MODEL -u TS_CLI_HOME
grep -qxF "HOME=${DEF}" "$ENVMARK" || fail "default home: profile not used: $(cat "$ENVMARK")"

echo "run-task model tests passed."
