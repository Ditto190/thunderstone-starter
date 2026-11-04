#!/usr/bin/env bash
# verify-lane.sh against a throwaway repo: branch, staged set, partial staging, header.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VL="${ROOT}/scripts/verify-lane.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "verify-lane test FAIL: $*" >&2; exit 1; }
repo="${TMP}/repo"
git init -q -b lane-x "$repo"
g() { git -C "$repo" -c user.name=t -c user.email=t@example.com "$@"; }
echo a >"${repo}/a.txt"; g add a.txt; g commit -q -m base
vl() { bash "$VL" --worktree "$repo" "$@"; }

set +e; out="$(vl --branch lane-x)"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'FAIL nothing staged' <<<"$out"; } || fail "empty stage should fail: $out"

echo b >"${repo}/b.txt"; echo a2 >"${repo}/a.txt"; g add a.txt b.txt
vl --branch lane-x --paths "b.txt a.txt" >/dev/null || fail "clean lane should pass"
set +e; out="$(vl --branch other)"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF "branch is 'lane-x'" <<<"$out"; } || fail "wrong branch not caught: $out"
set +e; out="$(vl --paths "a.txt")"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'extra: b.txt' <<<"$out"; } || fail "extra staged path not caught: $out"

echo a3 >>"${repo}/a.txt"
set +e; out="$(vl)"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'unstaged edits: a.txt' <<<"$out"; } || fail "partial staging not caught: $out"
g add a.txt

printf 'x \n' >"${repo}/ws.txt"; g add ws.txt
set +e; out="$(vl)"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'FAIL git diff --cached --check' <<<"$out"; } || fail "whitespace not caught: $out"
g rm -q --cached ws.txt

# Path with a space via --path; untracked replacement of a staged deletion is caught.
echo s >"${repo}/a b.txt"; g add "a b.txt"
vl --path "a b.txt" --paths "a.txt b.txt" >/dev/null || fail "--path with space should pass"
g rm -q --cached a.txt
set +e; out="$(vl)"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'unstaged edits: a.txt' <<<"$out"; } || fail "untracked replacement not caught: $out"
g add a.txt; g reset -q -- "a b.txt"; rm -f "${repo}/a b.txt"

ev="${TMP}/ev.md"
printf '{"goal":"g","owner":"o","success":"s","evidence_path":"e","approval":"a","return":"r"}\nbody\n' >"$ev"
vl --evidence "$ev" >/dev/null || fail "good header rejected"
printf '{"goal":"g","owner":"o"}\n' >"$ev"
set +e; out="$(vl --evidence "$ev")"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'missing keys: success,evidence_path,approval,return' <<<"$out"; } || fail "missing keys not caught: $out"
printf '# not json\n' >"$ev"
set +e; out="$(vl --evidence "$ev")"; code=$?; set -e
{ [[ "$code" -eq 1 ]] && grep -qF 'not JSON' <<<"$out"; } || fail "non-JSON header not caught: $out"
echo "verify-lane tests passed."
