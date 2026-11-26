#!/usr/bin/env bash
# run-task.sh must pass --model composer-2.5 by default, or --model "$TS_MODEL"
# when that env var is set. Stub agent only; PATH/HOME pinned like the other
# run-task tests so a real CLI cannot be reached.
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
mkdir -p "$STUB_BIN"
cat >"${STUB_BIN}/agent" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"${MARKER}"
exit 42
STUB
chmod +x "${STUB_BIN}/agent"

sandbox() {
  env -u BASH_ENV -u ENV HOME="$STUB_HOME" PATH="${STUB_BIN}:${SAFE_PATH}" "$@"
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
  rm -f "$MARKER"
  set +e
  out="$(sandbox THUNDERSTONE_OPERATIONAL_ROOT="$ops" "$@" bash "$RUN" "$BRIEF" 2>&1)"
  code=$?
  set -e
  [[ "$code" -eq 42 ]] || fail "expected stub exit 42, got ${code}: ${out}"
  [[ -s "$MARKER" ]] || fail "stub marker missing; something other than the stub ran"
  [[ "$(wc -l <"$MARKER")" -eq 1 ]] || fail "stub called more than once: $(cat "$MARKER")"
}

# Default: TS_MODEL unset -> --model composer-2.5
run_stub env -u TS_MODEL
grep -qF -- '--model composer-2.5' "$MARKER" || fail "default: missing --model composer-2.5: $(cat "$MARKER")"

# Override: TS_MODEL wins; default model string must not be passed
run_stub env TS_MODEL=test-model-override
grep -qF -- '--model test-model-override' "$MARKER" || fail "override: missing --model test-model-override: $(cat "$MARKER")"
grep -qF -- '--model composer-2.5' "$MARKER" && fail "override: default model still passed: $(cat "$MARKER")"

echo "run-task model tests passed."
