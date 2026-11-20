#!/usr/bin/env bash
# run-task.sh must not pass BASH_ENV/ENV to the agent. Uses only a stub agent:
# PATH is pinned to a stub dir + /usr/bin:/bin, HOME is a throwaway dir, and the
# stub's resolution is asserted before run-task.sh is ever called.
set -euo pipefail
if [[ -n "${BASH_ENV:-}" || -n "${ENV:-}" ]]; then
  exec env -u BASH_ENV -u ENV bash "${BASH_SOURCE[0]}" "$@"
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="${ROOT}/scripts/run-task.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "run-task BASH_ENV test FAIL: $*" >&2; exit 1; }

SAFE_PATH="/usr/bin:/bin"
for d in /usr/bin /bin; do
  [[ -e "${d}/agent" ]] && fail "${d}/agent exists; SAFE_PATH would reach a real agent"
done
STUB_HOME="${TMP}/home"
STUB_BIN="${STUB_HOME}/.local/bin"
MARKER="${TMP}/agent-stub-called"
mkdir -p "$STUB_BIN"
# The stub records what it inherited. /dev/null as BASH_ENV sources nothing, so PATH stays pinned.
cat >"${STUB_BIN}/agent" <<STUB
#!/bin/bash
printf 'BASH_ENV=%s ENV=%s\n' "\${BASH_ENV-unset}" "\${ENV-unset}" >>"${MARKER}"
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

set +e
out="$(sandbox BASH_ENV=/dev/null ENV=/dev/null THUNDERSTONE_OPERATIONAL_ROOT="$ops" bash "$RUN" "$BRIEF" 2>&1)"
code=$?
set -e
[[ "$code" -eq 42 ]] || fail "expected stub exit 42, got ${code}: ${out}"
[[ -s "$MARKER" ]] || fail "stub marker missing; something other than the stub ran"
[[ "$(wc -l <"$MARKER")" -eq 1 ]] || fail "stub called more than once"
grep -qx 'BASH_ENV=unset ENV=unset' "$MARKER" || fail "agent inherited: $(cat "$MARKER")"
echo "run-task BASH_ENV tests passed."
