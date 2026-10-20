#!/usr/bin/env bash
# Acceptance tests for scripts/catalog.mjs + scripts/select.sh.
# Silent when green; exits non-zero on the first failure.
# SELECT_TEST_VERBOSE=1 prints a line per test and a count.
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEL="$D/select.sh"
CAT_JS="$D/catalog.mjs"
T="$(mktemp -d)"
trap 'chmod -R u+rwx "$T" 2>/dev/null || true; rm -rf "$T"' EXIT
n=0
pass() { n=$((n + 1)); [ "${SELECT_TEST_VERBOSE:-0}" != 1 ] || echo "ok $n - $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
need() { command -v "$1" >/dev/null || fail "missing tool: $1"; }
need node; need jq

# --- fixtures (all under a temp dir; the real skills root is never touched) ---
R="$T/skills"; OUT="$T/outside"
mk() { # mk <root> <id> <frontmatter-lines...>
  local root="$1" id="$2"; shift 2
  mkdir -p "$root/$id"
  { echo '---'; printf '%s\n' "$@"; echo '---'; echo "# $id body"; } >"$root/$id/SKILL.md"
}
mk "$R" audit-area 'name: audit-area' 'description: >-' \
  '  Use when asked to audit one codebase area (bugs, dead code, flaky tests,' \
  '  docs drift, security hygiene, dependency risk). One area per run.'
mk "$R" review-prs 'name: review-prs' "description: 'Use when asked to review a pull request diff and leave comments.'"
mk "$R" deploy-helper 'name: deploy-helper' 'description: "Use when shipping a release: tag, changelog and deploy checklist."' 'tags: release, ship'
# private variants: every spelling must be denied
mk "$R" private-notes 'name: private-notes' 'description: Use when scanning personal gmail investment statuses and sourdough notes.' 'scope: private'
mk "$R" private-upper 'name: private-upper' 'description: Use when handling zebra ledgers privately.' 'scope: Private'
mk "$R" private-quoted 'name: private-quoted' 'description: Use when handling giraffe ledgers privately.' 'scope: "private"'
# unparseable / unknown scope / no frontmatter / duplicate keys => skipped
mk "$R" bad-front 'name: bad-front' 'description: Use when wombat frontmatter is broken.' 'this line is not yaml'
mk "$R" bad-scope 'name: bad-scope' 'description: Use when koala scope is unknown.' 'scope: confidential'
mk "$R" dup-keys 'name: dup-keys' 'description: Use when numbat keys repeat.' 'description: Use when numbat keys repeat again.'
mkdir -p "$R/no-front"; printf '# no frontmatter, wallaby\n' >"$R/no-front/SKILL.md"
# duplicate id in two folders: first sorted path wins
mk "$R/a" twin-dup 'name: twin-dup' 'description: Use when the first duplicate quokka applies.'
mk "$R/b" twin-dup 'name: twin-dup' 'description: Use when the second duplicate quokka applies.'
# a private id with a public twin: neither is indexed
mk "$R/c" ghost 'name: ghost' 'description: Use when the public ghost platypus applies.'
mk "$R/d" ghost 'name: ghost' 'description: Use when the private ghost platypus applies.' 'scope: private'
# outside the root: a valid public skill that symlinks must not pull in
mk "$OUT" escaped 'name: escaped' 'description: Use when the outsidemarker echidna applies.'
ln -s "$OUT/escaped" "$R/link-dir"
mkdir -p "$R/link-file"; ln -s "$OUT/escaped/SKILL.md" "$R/link-file/SKILL.md"

export THUNDERSTONE_SKILLS_ROOT="$R"
unset CATALOG EXTERNAL_LLMS_URL
GEN="$T/gen"; node "$CAT_JS" gen --out "$GEN" 2>"$T/gen.err"
CJ="$GEN/catalog.json"; LL="$GEN/llms.txt"
export CATALOG="$CJ"
ids() { jq -r '.items[].id' "$CJ" | sort | paste -sd,; }

# ---- PRIVATE DENY-BY-DEFAULT (first rule) ----
# P1 private never appears in catalog.json or llms.txt
jq -e . "$CJ" >/dev/null || fail "P1 catalog.json is not valid JSON"
for s in private-notes private-upper private-quoted zebra giraffe 'investment statuses'; do
  ! grep -qiF -- "$s" "$CJ" "$LL" || fail "P1 private item leaked into catalog output: $s"
done
pass "P1 private items absent from catalog.json and llms.txt"
# P2 private never returned by select, even on exact id or exact description words
for q in private-notes private-upper private-quoted "zebra ledgers" "giraffe ledgers" "scanning personal gmail investment statuses and sourdough notes"; do
  rc=0; out="$(bash "$SEL" "$q")" || rc=$?
  [[ $rc == 1 && $out == NO_MATCH ]] || fail "P2 private item returned for query: $q"
  rc=0; out="$(bash "$SEL" "$q" --json)" || rc=$?
  [ "$out" = '[]' ] || fail "P2 private item returned in --json for query: $q"
done
pass "P2 private items never returned by select (exact id and description)"
# P3 a hand-built catalog that lists a private item, or a stale 'shared' flag, is still denied
jq '.items += [{id:"private-notes",kind:"skill",description:"x",path:"'"$R"'/private-notes/SKILL.md",tags:[],scope:"private",cost:"S",kw:["private-notes","gmail"]},
               {id:"private-upper",kind:"skill",description:"x",path:"'"$R"'/private-upper/SKILL.md",tags:[],scope:"shared",cost:"S",kw:["private-upper","zebra"]}]' "$CJ" >"$T/tampered.json"
for q in private-notes private-upper zebra gmail; do
  rc=0; out="$(CATALOG="$T/tampered.json" bash "$SEL" "$q")" || rc=$?
  [[ $rc == 1 && $out == NO_MATCH ]] || fail "P3 tampered/stale catalog surfaced private item for: $q"
done
pass "P3 tampered or stale catalog cannot surface private items"
# P4 skipped, never guessed: malformed frontmatter, unknown scope, duplicate keys, none, symlinks, twins
[ "$(ids)" = "audit-area,deploy-helper,review-prs,twin-dup" ] || fail "P4 unexpected indexed ids: $(ids)"
for s in wombat koala numbat wallaby outsidemarker echidna platypus ghost; do
  ! grep -qiF -- "$s" "$CJ" "$LL" || fail "P4 skipped item leaked: $s"
  rc=0; bash "$SEL" "$s" >/dev/null || rc=$?
  [ "$rc" = 1 ] || fail "P4 skipped item selectable: $s"
done
pass "P4 malformed, unknown-scope, symlinked, out-of-root and private-twin items skipped"
# P5 item outside the root listed in a hand-built catalog is refused at select time
jq -n --arg p "$OUT/escaped/SKILL.md" '{version:1,generated:"x",items:[{id:"escaped",kind:"skill",description:"Use when the outsidemarker echidna applies.",path:$p,tags:[],scope:"shared",cost:"S",kw:["escaped","outsidemarker","echidna"]}]}' >"$T/outside.json"
rc=0; out="$(CATALOG="$T/outside.json" bash "$SEL" "escaped outsidemarker echidna")" || rc=$?
[[ $rc == 1 && $out == NO_MATCH ]] || fail "P5 out-of-root item returned"
jq -n --arg p "$R/link-file/SKILL.md" '{version:1,generated:"x",items:[{id:"link-file",kind:"skill",description:"Use when the outsidemarker echidna applies.",path:$p,tags:[],scope:"shared",cost:"S",kw:["link-file","outsidemarker"]}]}' >"$T/link.json"
rc=0; out="$(CATALOG="$T/link.json" bash "$SEL" "outsidemarker")" || rc=$?
[[ $rc == 1 && $out == NO_MATCH ]] || fail "P5 symlinked item returned"
pass "P5 out-of-root and symlinked paths refused at select time"
# P6 a private flip after generation is honoured (stale catalog)
mk "$R" flip-me 'name: flip-me' 'description: Use when the flipcheck narwhal applies.'
node "$CAT_JS" gen --out "$T/flip" 2>/dev/null
[ "$(CATALOG="$T/flip/catalog.json" bash "$SEL" flipcheck | cut -f3)" = flip-me ] || fail "P6 setup: flip-me not selectable"
mk "$R" flip-me 'name: flip-me' 'description: Use when the flipcheck narwhal applies.' 'scope: private'
rc=0; out="$(CATALOG="$T/flip/catalog.json" bash "$SEL" flipcheck)" || rc=$?
[[ $rc == 1 && $out == NO_MATCH ]] || fail "P6 stale catalog returned a skill that is now private"
rm -rf "$R/flip-me"
pass "P6 skill flipped to private after generation is denied"
# P7 --external is off by default: curl is never called; when on, the request carries no task text
mkdir -p "$T/bin"
cat >"$T/bin/curl" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$T/curl.log"
printf -- '- [pdf-tool](https://example.invalid/pdf): review pdf documents\n'
SH
chmod +x "$T/bin/curl"
secret_task="review pdf quokka zzsecrettask"
PATH="$T/bin:$PATH" bash "$SEL" "$secret_task" >/dev/null || true
[ ! -e "$T/curl.log" ] || fail "P7 curl called without --external"
out="$(PATH="$T/bin:$PATH" bash "$SEL" "$secret_task" --external)" || true
[ -s "$T/curl.log" ] || fail "P7 --external did not fetch"
! grep -qiE "zzsecrettask|quokka|review" "$T/curl.log" || fail "P7 task text sent in the external request"
[ "$(wc -l <"$T/curl.log")" = 1 ] || fail "P7 expected exactly one external request"
grep -q 'awesome-copilot' "$T/curl.log" || fail "P7 unexpected external request target"
grep -q 'pdf-tool' <<<"$out" || fail "P7 external matches not shown"
pass "P7 --external off by default; request contains no task text"

# ---- plan section 6 acceptance tests ----
# 1 gen on fixtures -> valid JSON; private excluded; ids equal folder names
jq -e '.version == 1 and (.items | length) == 4' "$CJ" >/dev/null || fail "1 expected 4 public items"
for id in $(jq -r '.items[].id' "$CJ"); do
  p="$(jq -r --arg id "$id" '.items[] | select(.id == $id) | .path' "$CJ")"
  [ "$(basename "$(dirname "$p")")" = "$id" ] || fail "1 id differs from folder name: $id"
done
[ "$(jq -r '.items[] | select(.id == "audit-area") | .description' "$CJ" | cut -c1-29)" = "Use when asked to audit one c" ] || fail "1 folded description not parsed"
[ "$(jq -r '.items[] | select(.id == "review-prs") | .description' "$CJ" | cut -c1-12)" = "Use when ask" ] || fail "1 quoted description not parsed"
pass "1 gen: valid JSON, public items only, ids equal folder names"
# 2 duplicate id -> one item, first path wins
[ "$(jq '[.items[] | select(.id == "twin-dup")] | length' "$CJ")" = 1 ] || fail "2 duplicate id not collapsed"
[ "$(jq -r '.items[] | select(.id == "twin-dup") | .path' "$CJ")" = "$R/a/twin-dup/SKILL.md" ] || fail "2 first path did not win"
pass "2 duplicate id collapses to the first path"
# 3 select hits the right skill
rc=0; out="$(bash "$SEL" "audit dead code")" || rc=$?
[[ $rc == 0 && "$(head -1 <<<"$out" | cut -f3)" == audit-area ]] || fail "3 audit dead code did not pick audit-area"
pass "3 select 'audit dead code' -> audit-area"
# 4 no match
rc=0; out="$(bash "$SEL" "bake a sourdough loaf")" || rc=$?
[[ $rc == 1 && $out == NO_MATCH ]] || fail "4 expected exit 1 + NO_MATCH"
pass "4 no match -> exit 1 + NO_MATCH"
# 4b --json no match still exits 1
rc=0; out="$(bash "$SEL" "bake a sourdough loaf" --json)" || rc=$?
[[ $rc == 1 && $out == '[]' ]] || fail "4b --json no-match expected exit 1 and []"
pass "4b --json no-match -> exit 1 + []"
# 4c unreadable subdirectory is skipped; other skills stay indexed
if [ "$(id -u)" != 0 ]; then
  mkdir -p "$R/sealed"
  chmod 000 "$R/sealed"
  node "$CAT_JS" gen --root "$R" --out "$T/sealed-gen" >/dev/null
  jq -e --arg id audit-area '.items[] | select(.id == $id)' "$T/sealed-gen/catalog.json" >/dev/null || fail "4c audit-area dropped when a subdir is unreadable"
  chmod 755 "$R/sealed"
  pass "4c unreadable subdir skipped"
fi
# 4d default catalog for root A is ignored when --root B and CATALOG is unset
LAY="$T/layout"
mkdir -p "$LAY/scripts" "$LAY/catalog" "$T/rootA" "$T/rootB"
ln -s "$CAT_JS" "$LAY/scripts/catalog.mjs"
ln -s "$SEL" "$LAY/scripts/select.sh"
mk "$T/rootA" only-a 'name: only-a' 'description: Use when the alphaquoll marker applies.'
mk "$T/rootB" only-b 'name: only-b' 'description: Use when the bravoquoll marker applies.'
node "$CAT_JS" gen --root "$T/rootA" --out "$LAY/catalog" >/dev/null
rc=0; out="$(env -u CATALOG -u THUNDERSTONE_SKILLS_ROOT bash "$LAY/scripts/select.sh" "bravoquoll" --root "$T/rootB")" || rc=$?
[[ $rc == 0 && "$(head -1 <<<"$out" | cut -f3)" == only-b ]] || fail "4d --root did not override the default catalog"
pass "4d --root B ignores default catalog for root A"
# 5 private on an exact id match: covered by P2/P3; assert once more on the plain id
rc=0; out="$(bash "$SEL" "private-notes")" || rc=$?
[[ $rc == 1 && $out == NO_MATCH ]] || fail "5 private id matched"
pass "5 private item never appears, even on exact id"
# 6 --json, --top, --kind
bash "$SEL" "review audit release pull request code" --json | jq -e 'length <= 3' >/dev/null || fail "6 --json length"
[ "$(bash "$SEL" "review audit release pull request code" --top 1 | wc -l)" = 1 ] || fail "6 --top 1"
rc=0; out="$(bash "$SEL" "audit dead code" --kind agent)" || rc=$?
[[ $rc == 1 && $out == NO_MATCH ]] || fail "6 --kind agent should be NO_MATCH"
rc=0; bash "$SEL" "audit" --top 0 >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "6 bad --top should exit 2"
pass "6 --json, --top 1, --kind agent"
# 7 output size guard
for q in "audit review release code pull request dead tests docs" "ship release changelog deploy tag"; do
  [ "$(bash "$SEL" "$q" | wc -c)" -le 700 ] || fail "7 top-3 output over 700 bytes"
done
pass "7 top-3 output <= 700 bytes"
# 8 --external offline still exits 0 with local results
rc=0; out="$(EXTERNAL_LLMS_URL=http://127.0.0.1:9/llms.txt bash "$SEL" "audit dead code" --external)" || rc=$?
[ "$rc" = 0 ] || fail "8 offline --external exit $rc"
grep -q audit-area <<<"$out" || fail "8 local results missing"
grep -q '^--- external' <<<"$out" || fail "8 external banner missing"
pass "8 --external offline: exit 0 and local results"
# 9 idempotence
node "$CAT_JS" gen 2>/dev/null | jq -S '.items' >"$T/g1.json"
node "$CAT_JS" gen 2>/dev/null | jq -S '.items' >"$T/g2.json"
cmp -s "$T/g1.json" "$T/g2.json" || fail "9 gen not idempotent"
pass "9 gen is idempotent"
# 10 secret hygiene on generated output
! grep -rEi '(api[_-]?key|token|secret)=' "$GEN" || fail "10 secret-like text in catalog output"
mk "$R" leaky 'name: leaky' 'description: Use when deploying with api_key=abcdef0123456789 inline.'
node "$CAT_JS" gen 2>/dev/null | jq -e '[.items[].id] | index("leaky") | not' >/dev/null || fail "10 secret-like description was indexed"
rm -rf "$R/leaky"
pass "10 no secret-like text in catalog output"

# 11 selection quality gate against the real shared skills (runs only when THUNDERSTONE_REAL_SKILLS points at the real skills folder)
REAL="${THUNDERSTONE_REAL_SKILLS:-}"
if [ -n "$REAL" ] && [ -d "$REAL" ] && [ -f "$REAL/audit-area/SKILL.md" ]; then
  unset THUNDERSTONE_SKILLS_ROOT CATALOG
  export THUNDERSTONE_SKILLS_ROOT="$REAL"
  pairs=(
    "audit the flaky tests and dead code in one area|audit-area"
    "check docs drift and dependency risk|audit-area"
    "write a brief for Cursor-Runner|brief-and-report"
    "Cursor-Runner finished, what report format do I use|brief-and-report"
    "unsure who to report to or what needs DT approval|house-rules"
    "start of a work turn, which standing rules apply|house-rules"
    "which ts-* wrapper do I use for glab|tool-howtos"
    "how do I call Context7 or Githits on the VM|tool-howtos"
  )
  top1=0; top3=0
  for p in "${pairs[@]}"; do
    q="${p%|*}"; want="${p##*|}"
    got="$(bash "$SEL" "$q" | cut -f3)" || got=""
    [ "$(head -1 <<<"$got")" = "$want" ] && top1=$((top1 + 1))
    grep -qx "$want" <<<"$got" && top3=$((top3 + 1))
  done
  [[ $top1 -ge 7 && $top3 -eq 8 ]] || fail "11 quality gate: top1=$top1/8 top3=$top3/8"
  pass "11 quality gate: top1=$top1/8 top3=$top3/8"
else
  [ "${SELECT_TEST_VERBOSE:-0}" != 1 ] || echo "skip 11 - THUNDERSTONE_REAL_SKILLS not set"
fi
[ "${SELECT_TEST_VERBOSE:-0}" != 1 ] || echo "select-test: $n passed"
