#!/usr/bin/env bash
# Acceptance tests for scripts/skills-sync-check.sh. Silent when green.
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="$D/skills-sync-check.sh"
CAT="$D/catalog.mjs"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

R="$T/canon"
M="$T/mirror"
mkdir -p "$R" "$M"

skill() { # skill ROOT ID [extra frontmatter...]
  local root=$1 id=$2
  shift 2
  mkdir -p "$root/$id"
  {
    echo '---'
    echo "name: $id"
    echo "description: Use when testing $id."
    if [ "$#" -gt 0 ]; then printf '%s\n' "$@"; fi
    echo '---'
    echo "# $id"
  } >"$root/$id/SKILL.md"
}

skill "$R" alpha
skill "$R" beta 'scope: private'
cp -a "$R/alpha" "$M/alpha"
cp -a "$R/beta" "$M/beta"

out="$T/out"
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --quiet >"$out" 2>"$T/err"
code=$?
set -e
[ "$code" -eq 0 ] || fail "identical mirror exit $code"
[ ! -s "$out" ] || fail "quiet identical produced output"

# drift
printf '\nchanged\n' >>"$M/alpha/SKILL.md"
set +e
bash "$CHK" --canonical "$R" --mirror "$M" >"$out"
code=$?
set -e
[ "$code" -eq 1 ] || fail "drift exit $code"
grep -q $'^drift\talpha\t' "$out" || fail "drift row missing"

# missing
rm -rf "$M/beta"
set +e
bash "$CHK" --canonical "$R" --mirror "$M" >"$out"
code=$?
set -e
[ "$code" -eq 1 ] || fail "missing exit $code"
grep -q $'^missing\tbeta\t' "$out" || fail "missing row missing"

# symlink to canonical
rm -rf "$M"
mkdir -p "$M"
ln -s "$R/alpha" "$M/alpha"
ln -s "$R/beta" "$M/beta"
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --quiet >"$out"
code=$?
set -e
[ "$code" -eq 0 ] || fail "symlink exit $code"

# extra in mirror
mkdir -p "$M"
skill "$M" extra-only
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --quiet >"$out"
code=$?
set -e
[ "$code" -eq 0 ] || fail "extra exit $code"
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --strict >"$out"
code=$?
set -e
[ "$code" -eq 1 ] || fail "strict extra exit $code"
grep -q $'^extra\textra-only\t' "$out" || fail "extra row missing"

# private stays out of a fresh catalog; hand-edited catalog that adds it fails
rm -rf "$M/extra-only"
GEN="$T/cat"
node "$CAT" gen --root "$R" --out "$GEN" 2>/dev/null
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --catalog "$GEN" --quiet >"$out"
code=$?
set -e
[ "$code" -eq 0 ] || fail "private absent exit $code"
node --input-type=module - "$GEN/catalog.json" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const p = process.argv[2];
const cat = JSON.parse(readFileSync(p, 'utf8'));
cat.items.push({ id: 'beta', kind: 'skill', description: 'nope', scope: 'private' });
writeFileSync(p, JSON.stringify(cat));
JS
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --catalog "$GEN" >"$out"
code=$?
set -e
[ "$code" -eq 1 ] || fail "private in catalog exit $code"
grep -q $'^pickup\t' "$out" || fail "pickup row missing"

# stale catalog
node "$CAT" gen --root "$R" --out "$GEN" 2>/dev/null
touch -d '1 second ago' "$GEN/catalog.json" 2>/dev/null || sleep 1
touch "$R/alpha/SKILL.md"
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --catalog "$GEN" >"$out"
code=$?
set -e
[ "$code" -eq 1 ] || fail "stale exit $code"
grep -q $'^stale\t' "$out" || fail "stale row missing"

# print-fix prints commands and changes nothing
rm -rf "$M"
mkdir -p "$M"
cp -a "$R/alpha" "$M/alpha"
cp -a "$R/beta" "$M/beta"
printf '\nchanged\n' >>"$M/alpha/SKILL.md"
before=$(find "$M" -printf '%p %T@\n' | sort | sha256sum)
set +e
bash "$CHK" --canonical "$R" --mirror "$M" --print-fix >"$out"
code=$?
set -e
[ "$code" -eq 1 ] || fail "print-fix exit $code"
grep -q 'rsync -a --delete' "$out" || fail "print-fix did not print rsync"
after=$(find "$M" -printf '%p %T@\n' | sort | sha256sum)
[ "$before" = "$after" ] || fail "print-fix changed the mirror"

# bad args
set +e
bash "$CHK" --nope >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "bad flag exit $code"
set +e
bash "$CHK" --canonical >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "missing value exit $code"
set +e
bash "$CHK" --canonical "$T/does-not-exist" >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "missing root exit $code"

# no mirrors: canonical + pickup only
unset SKILLS_MIRRORS
node "$CAT" gen --root "$R" --out "$GEN" 2>/dev/null
# catalog is older than the touched skill, so point at a fresh one
set +e
bash "$CHK" --canonical "$R" --catalog "$GEN" --quiet >"$out"
code=$?
set -e
# may be stale because we touched alpha; regenerate after touch
node "$CAT" gen --root "$R" --out "$GEN" 2>/dev/null
set +e
bash "$CHK" --canonical "$R" --catalog "$GEN" --quiet >"$out"
code=$?
set -e
[ "$code" -eq 0 ] || fail "no-mirror exit $code"
[ ! -s "$out" ] || fail "no-mirror quiet produced output"
if grep -q $'\t'"$M"$'\t' "$out"; then
  fail "no-mirror printed a mirror row"
fi

# review fixes (#51 cubic P2): symlink targets, llms prefix, rel-path extras, symlinked extras
R2="$T/canon2"; M2="$T/mirror2"; X="$T/ext"
mkdir -p "$R2" "$M2" "$X"
skill "$R2" gamma
printf 'a\n' >"$X/a.txt"; printf 'b\n' >"$X/b.txt"
ln -s "$X/a.txt" "$R2/gamma/ref.txt"
cp -a "$R2/gamma" "$M2/gamma"
set +e; bash "$CHK" --canonical "$R2" --mirror "$M2" --quiet >"$out"; code=$?; set -e
[ "$code" -eq 0 ] || fail "same symlink target exit $code"
rm "$M2/gamma/ref.txt"; ln -s "$X/b.txt" "$M2/gamma/ref.txt"
set +e; bash "$CHK" --canonical "$R2" --mirror "$M2" >"$out"; code=$?; set -e
[ "$code" -eq 1 ] || fail "symlink target drift exit $code"
grep -q $'^drift\tgamma\t' "$out" || fail "symlink target drift row missing"
rm -rf "$M2/gamma"; cp -a "$R2/gamma" "$M2/gamma"
# same id at another path in the mirror is an extra under --strict
skill "$M2/nested" gamma
set +e; bash "$CHK" --canonical "$R2" --mirror "$M2" --strict >"$out"; code=$?; set -e
[ "$code" -eq 1 ] || fail "strict shadow path exit $code"
grep -q $'^extra\tgamma\tnested/gamma' <(cut -f1,2,4 "$out") || fail "shadow extra row missing"
rm -rf "$M2/nested"
# symlinked extra skill dir is an extra under --strict
skill "$X" linked
ln -s "$X/linked" "$M2/linked"
set +e; bash "$CHK" --canonical "$R2" --mirror "$M2" --strict >"$out"; code=$?; set -e
[ "$code" -eq 1 ] || fail "strict symlinked extra exit $code"
grep -q $'^extra\tlinked\t' "$out" || fail "symlinked extra row missing"
rm "$M2/linked"
# llms.txt: an id only mentioned in another entry's text is not a pickup
G2="$T/cat2"
node "$CAT" gen --root "$R2" --out "$G2" 2>/dev/null
set +e; bash "$CHK" --canonical "$R2" --catalog "$G2" --quiet >"$out"; code=$?; set -e
[ "$code" -eq 0 ] || fail "llms fresh exit $code"
printf -- '- [other](x): see [gamma] too\n' >"$G2/llms.txt"
touch "$G2/catalog.json"
set +e; bash "$CHK" --canonical "$R2" --catalog "$G2" >"$out"; code=$?; set -e
[ "$code" -eq 1 ] || fail "llms mention-only exit $code"
grep -q $'^pickup\tgamma\tcatalog\tmissing-from-llms' "$out" || fail "llms missing row absent"

echo "skills-sync tests passed"
