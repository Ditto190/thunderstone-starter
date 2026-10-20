#!/usr/bin/env bash
set -euo pipefail

# Never inherit BASH_ENV: on the VM it points at vm-ops-env, which prepends the
# real ~/.local/bin (absolute path) to PATH in every child bash and so re-exposes the
# real Cursor CLI. Re-exec the whole test without it (and without ENV).
if [[ -n "${BASH_ENV:-}" || -n "${ENV:-}" ]]; then
  exec env -u BASH_ENV -u ENV bash "${BASH_SOURCE[0]}" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="${ROOT}/scripts/run-task.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "usage-limit test FAIL: $*" >&2
  exit 1
}

# Minimal system dirs only. Refuse to run if any of them holds an agent.
SAFE_PATH="/usr/bin:/bin"
IFS=: read -r -a safe_dirs <<<"$SAFE_PATH"
for d in "${safe_dirs[@]}"; do
  [[ -e "${d}/agent" ]] && fail "${d}/agent exists; SAFE_PATH would reach a real agent"
done

# run-task.sh prepends "$HOME/.local/bin", so HOME is a throwaway dir and the
# stub lives in its .local/bin (also first on PATH). The stub records each call.
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
EMPTY_HOME="${TMP}/home-empty"
mkdir -p "${EMPTY_HOME}/.local/bin"

# Run a command in the exact env run-task.sh gets (no BASH_ENV/ENV, pinned PATH/HOME).
sandbox() {
  local home="$1"
  shift
  env -u BASH_ENV -u ENV HOME="$home" PATH="${home}/.local/bin:${SAFE_PATH}" "$@"
}

# Assert agent resolution inside the sandbox, mirroring run-task.sh line 3.
# shellcheck disable=SC2016  # expand inside the sandbox shell
resolved="$(sandbox "$STUB_HOME" bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v agent' || true)"
[[ "$resolved" == "${STUB_BIN}/agent" ]] || fail "agent resolves to '${resolved}', not the stub"
# shellcheck disable=SC2016
if sandbox "$EMPTY_HOME" bash -c 'export PATH="$HOME/.local/bin:$PATH"; command -v agent' >/dev/null 2>&1; then
  fail "an agent is reachable with an empty HOME and SAFE_PATH"
fi

TODAY="$(TZ=Australia/Sydney date +%F)"
BRIEF="${TMP}/brief.md"
printf 'dummy brief\n' >"$BRIEF"

# 1) Usage-limit recorded today: exit 75 before any agent call.
ops_blocked="${TMP}/ops-blocked"
mkdir -p "${ops_blocked}/state"
printf '| %s | cursor | usage-limit |\n' "$TODAY" >"${ops_blocked}/state/cloud-agent-ledger.md"
set +e
out="$(sandbox "$STUB_HOME" THUNDERSTONE_OPERATIONAL_ROOT="$ops_blocked" bash "$RUN" "$BRIEF" 2>&1)"
code=$?
set -e
[[ "$code" -eq 75 ]] || fail "blocked: expected exit 75, got ${code}: ${out}"
grep -qF 'blocked: usage-limit' <<<"$out" || fail "blocked: missing 'blocked: usage-limit': ${out}"
[[ ! -e "$MARKER" ]] || fail "blocked: agent stub was invoked"

# 2) Ledger clear: guard passes and exec reaches the stub (exit 42 + marker), never a real agent.
ops_clear="${TMP}/ops-clear"
mkdir -p "${ops_clear}/state"
printf '| 2000-01-01 | cursor | usage-limit |\n' >"${ops_clear}/state/cloud-agent-ledger.md"
set +e
out="$(sandbox "$STUB_HOME" THUNDERSTONE_OPERATIONAL_ROOT="$ops_clear" bash "$RUN" "$BRIEF" 2>&1)"
code=$?
set -e
[[ "$code" -eq 42 ]] || fail "clear: expected stub exit 42, got ${code}: ${out}"
[[ -s "$MARKER" ]] || fail "clear: stub marker missing; something other than the stub ran"
[[ "$(wc -l <"$MARKER")" -eq 1 ]] || fail "clear: stub called more than once"
grep -qF -- '-p --trust --force' "$MARKER" || fail "clear: stub args missing '-p --trust --force'"

# 3) Ledger clear, no agent anywhere: exit 1 with install hint.
rm -f "$MARKER"
set +e
out="$(sandbox "$EMPTY_HOME" THUNDERSTONE_OPERATIONAL_ROOT="$ops_clear" bash "$RUN" "$BRIEF" 2>&1)"
code=$?
set -e
[[ "$code" -eq 1 ]] || fail "no-agent: expected exit 1, got ${code}: ${out}"
grep -qF 'Install Cursor CLI first' <<<"$out" || fail "no-agent: missing install hint: ${out}"
[[ ! -e "$MARKER" ]] || fail "no-agent: agent stub was invoked"

echo "run-task usage-limit tests passed."
