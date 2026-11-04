#!/usr/bin/env bash
# ci-mimic.sh hides box-only tools (not tmux: CI installs it) and the Cursor CLI, strips BASH_ENV, keeps CI tools.
# Uses only the `--` command override, so it never recurses into npm test or runs an agent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CM="${ROOT}/scripts/ci-mimic.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "ci-mimic test FAIL: $*" >&2; exit 1; }
# Fake box tools on PATH so the hide list has something to hide on any machine.
fake="${TMP}/fakebin"
mkdir -p "$fake"
for t in tmux rclone fzf agent cursor-agent keepme; do printf '#!/bin/sh\nexit 0\n' >"${fake}/${t}"; chmod +x "${fake}/${t}"; done
log="${TMP}/cm.log"
# shellcheck disable=SC2016  # expand inside the mimic shell
probe='for t in tmux rclone fzf agent cursor-agent keepme node git; do command -v "$t" >/dev/null && echo "has:$t" || echo "no:$t"; done; echo "bash_env:${BASH_ENV-unset}"'
PATH="${fake}:${PATH}" BASH_ENV=/dev/null bash "$CM" --log "$log" -- bash -c "$probe" >"${TMP}/out" || fail "probe run failed: $(cat "${TMP}/out")"
for t in rclone fzf agent cursor-agent; do grep -qx "no:$t" "$log" || fail "$t not hidden"; done
for t in tmux keepme node git; do grep -qx "has:$t" "$log" || fail "$t should stay visible"; done
grep -qx 'bash_env:unset' "$log" || fail "BASH_ENV leaked"
grep -qF 'ci-mimic: PASS' "${TMP}/out" || fail "no PASS line"
PATH="${fake}:${PATH}" bash "$CM" --hide keepme --log "$log" -- bash -c "$probe" >/dev/null || fail "custom hide run failed"
{ grep -qx 'no:keepme' "$log" && grep -qx 'no:agent' "$log"; } || fail "--hide must hide keepme and still hide agent"
grep -qx 'has:rclone' "$log" || fail "--hide replaces the default list"
set +e; bash "$CM" --log "$log" -- false >"${TMP}/out"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'ci-mimic: FAIL custom command rc=1' "${TMP}/out"; } || fail "failing step not reported: $(cat "${TMP}/out")"
# Secrets in custom args never reach the label; HOME is isolated; first failure is kept.
PATH="${fake}:${PATH}" bash "$CM" --log "$log" -- bash -c 'echo "home:$HOME"' tok-SECRET123 >"${TMP}/out" || fail "label run failed"
if grep -qF SECRET123 "${TMP}/out" "$log"; then fail "custom args leaked into label"; fi
grep -qF 'ok   custom command' "${TMP}/out" || fail "constant label missing"
grep -q "^home:${HOME}\$" "$log" && fail "HOME not isolated"
rel="${TMP}/rel"; mkdir -p "${rel}/tools"; printf '#!/bin/sh\necho relok\n' >"${rel}/tools/reltool"; chmod +x "${rel}/tools/reltool"
(cd "$rel" && PATH="tools:${PATH}" bash "$CM" --log "$log" -- reltool >/dev/null) || fail "relative PATH entry unreachable"
repo="${TMP}/r"; mkdir -p "${repo}/scripts"; cp "$CM" "${repo}/scripts/"; git init -q "$repo"
printf '{"scripts":{"test":"true"}}\n' >"${repo}/package.json"; printf 'x \n' >"${repo}/ws.txt"; git -C "$repo" add ws.txt
set +e; bash "${repo}/scripts/ci-mimic.sh" --log "$log" >"${TMP}/out"; code=$?; set -e
{ [[ "$code" -ne 0 ]] && grep -qF 'ci-mimic: FAIL (hidden' "${TMP}/out"; } || fail "early failure masked by later pass: $(cat "${TMP}/out")"
echo "ci-mimic tests passed."
