#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="${ROOT}/.cursor/hooks/session-skills.sh"
END="${ROOT}/.cursor/hooks/session-end-ci.sh"
HOOKS_JSON="${ROOT}/.cursor/hooks.json"
TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

failures=0

fail() {
  echo "session-hooks test FAIL: $1" >&2
  failures=1
}

assert_exact() {
  local name="$1" expected="$2" out="$3"
  if [ "$out" != "$expected" ]; then
    echo "session-hooks test FAIL: $name" >&2
    echo "  expected: $expected" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

assert_json() {
  local name="$1" out="$2"
  if ! printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{JSON.parse(s);});'; then
    echo "session-hooks test FAIL: $name (invalid JSON)" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

assert_has() {
  local name="$1" needle="$2" out="$3"
  if ! grep -qF "$needle" <<<"$out"; then
    echo "session-hooks test FAIL: $name" >&2
    echo "  missing: $needle" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

assert_lacks() {
  local name="$1" needle="$2" out="$3"
  if grep -qF "$needle" <<<"$out"; then
    echo "session-hooks test FAIL: $name" >&2
    echo "  unexpected: $needle" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -b main >/dev/null
    git config user.email "Ditto190@users.noreply.github.com"
    git config user.name "Ditto190"
    echo seed >README.md
    printf '%s\n' '.state/' >.gitignore
    git add README.md .gitignore
    git commit -m "chore: seed" >/dev/null
  )
}

install_npm() {
  local bin="$1" marker="$2" mode="$3"
  mkdir -p "$bin"
  cat >"${bin}/npm" <<EOF
#!/bin/sh
echo ran >>"${marker}"
case "${mode}" in
  fail) exit 1 ;;
  sleep) sleep 5; exit 0 ;;
esac
exit 0
EOF
  chmod +x "${bin}/npm"
}

run_skills() {
  (
    cd "$1"
    shift
    printf '{}\n' | env "$@" bash "$SKILLS"
  )
}

run_end() {
  local dir="$1"
  shift
  (
    cd "$dir"
    # BASH_ENV (box login env) can re-prepend PATH in child bash and hide the npm stub.
    printf '{}\n' | env -u BASH_ENV "$@" bash "$END"
  )
}

# hooks.json: every command has timeout 5 and failClosed false
node -e '
const fs = require("fs");
const doc = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const hooks = doc.hooks || {};
let n = 0;
for (const list of Object.values(hooks)) {
  for (const h of list) {
    n += 1;
    if (h.timeout !== 5 || h.failClosed !== false) {
      console.error("bad hook entry", JSON.stringify(h));
      process.exit(1);
    }
  }
}
if (n < 3) {
  console.error("expected stage-router, session-skills and session-end");
  process.exit(1);
}
const start = (hooks.sessionStart || []).map((h) => h.command);
const end = (hooks.sessionEnd || []).map((h) => h.command);
if (!start.includes(".cursor/hooks/stage-router.sh")) process.exit(1);
if (!start.includes(".cursor/hooks/session-skills.sh")) process.exit(1);
if (!end.includes(".cursor/hooks/session-end-ci.sh")) process.exit(1);
' "$HOOKS_JSON" || fail "hooks.json contract"

# JSON validity + missing skills
empty="${TMP_BASE}/empty"
mkdir -p "$empty"
out="$(run_skills "$empty" HOME="${TMP_BASE}/no-home" THUNDERSTONE_SKILLS_ROOT=)"
assert_exact "no-skills" '{}' "$out"
assert_json "no-skills-json" "$out"

# Found and missing
home="${TMP_BASE}/home"
mkdir -p "${home}/.cursor/skills/lean-ctx" "${home}/.cursor/skills/caveman"
echo "# lean" >"${home}/.cursor/skills/lean-ctx/SKILL.md"
echo "# cave" >"${home}/.cursor/skills/caveman/SKILL.md"
out="$(run_skills "$empty" HOME="$home" THUNDERSTONE_SKILLS_ROOT=)"
assert_json "skills-json" "$out"
assert_has "skills-found-lean" "lean-ctx (~/.cursor/skills/lean-ctx/SKILL.md)" "$out"
assert_has "skills-found-caveman" "caveman (~/.cursor/skills/caveman/SKILL.md)" "$out"
assert_has "skills-missing" "missing: grok-agent-ops" "$out"

# Root env wins over home
root_skills="${TMP_BASE}/skills-root"
mkdir -p "${root_skills}/grok-agent-ops"
echo "# g" >"${root_skills}/grok-agent-ops/SKILL.md"
out="$(run_skills "$empty" HOME="$home" THUNDERSTONE_SKILLS_ROOT="$root_skills")"
assert_has "root-wins" "grok-agent-ops (\$THUNDERSTONE_SKILLS_ROOT/grok-agent-ops/SKILL.md)" "$out"
assert_lacks "root-not-home-grok" "grok-agent-ops (~/" "$out"

# CI note only when exit != 0
ci_dir="${TMP_BASE}/ci-note"
mkdir -p "${ci_dir}/.state/session-ci"
printf '%s\n' '{"head":"abc","started":"t","finished":"t","exit":0,"log":".state/session-ci/last.log"}' \
  >"${ci_dir}/.state/session-ci/last.json"
out="$(run_skills "$ci_dir" HOME="${TMP_BASE}/no-home" THUNDERSTONE_SKILLS_ROOT=)"
assert_exact "green-ci-silent" '{}' "$out"
assert_lacks "green-no-ci-text" "last local CI" "$out"

printf '%s\n' '{"head":"abc","started":"t","finished":"t","exit":2,"log":".state/session-ci/last.log"}' \
  >"${ci_dir}/.state/session-ci/last.json"
out="$(run_skills "$ci_dir" HOME="$home" THUNDERSTONE_SKILLS_ROOT=)"
assert_json "fail-ci-json" "$out"
assert_has "fail-ci-text" "last local CI: FAIL (exit 2, .state/session-ci/last.log)" "$out"

# sessionEnd JSON + non-git
nogit="${TMP_BASE}/nogit"
mkdir -p "$nogit"
out="$(run_end "$nogit")"
assert_exact "non-git" '{}' "$out"
assert_json "non-git-json" "$out"

# Disable
repo="${TMP_BASE}/disable"
init_repo "$repo"
echo dirty >>"${repo}/README.md"
marker="${TMP_BASE}/disable.marker"
bin="${TMP_BASE}/bin-disable"
install_npm "$bin" "$marker" ok
out="$(run_end "$repo" PATH="${bin}:${PATH}" SESSION_CI_DISABLE=1)"
assert_exact "disable-json" '{}' "$out"
if [ -f "$marker" ]; then
  fail "disable still ran npm"
fi

# Fast return while npm sleeps
repo="${TMP_BASE}/fast"
init_repo "$repo"
echo dirty >>"${repo}/README.md"
marker="${TMP_BASE}/fast.marker"
bin="${TMP_BASE}/bin-fast"
install_npm "$bin" "$marker" sleep
start="$SECONDS"
out="$(run_end "$repo" PATH="${bin}:${PATH}" SESSION_CI_TIMEOUT=8)"
elapsed=$((SECONDS - start))
assert_exact "fast-json" '{}' "$out"
if [ "$elapsed" -ge 2 ]; then
  fail "sessionEnd took ${elapsed}s"
fi

# Unchanged fingerprint skips a second launch
repo="${TMP_BASE}/once"
init_repo "$repo"
echo dirty >>"${repo}/README.md"
marker="${TMP_BASE}/once.marker"
bin="${TMP_BASE}/bin-once"
install_npm "$bin" "$marker" ok
out="$(run_end "$repo" PATH="${bin}:${PATH}" SESSION_CI_TIMEOUT=30)"
assert_json "once-json" "$out"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "${repo}/.state/session-ci/last.json" ] && break
  sleep 0.2
done
if [ ! -f "${repo}/.state/session-ci/last.json" ]; then
  fail "runner did not write last.json"
fi
before="$(wc -l <"$marker" | tr -d ' ')"
out="$(run_end "$repo" PATH="${bin}:${PATH}" SESSION_CI_TIMEOUT=30)"
assert_exact "skip-unchanged" '{}' "$out"
sleep 0.5
after="$(wc -l <"$marker" | tr -d ' ')"
if [ "$before" != "$after" ]; then
  fail "unchanged fingerprint re-ran npm (${before} -> ${after})"
fi

# Live lock skips
repo="${TMP_BASE}/locked"
init_repo "$repo"
echo dirty >>"${repo}/README.md"
marker="${TMP_BASE}/lock.marker"
bin="${TMP_BASE}/bin-lock"
install_npm "$bin" "$marker" ok
mkdir -p "${repo}/.state/session-ci"
sleep 30 &
sleep_pid=$!
echo "$sleep_pid" >"${repo}/.state/session-ci/lock"
out="$(run_end "$repo" PATH="${bin}:${PATH}")"
assert_exact "lock-json" '{}' "$out"
kill "$sleep_pid" 2>/dev/null || true
wait "$sleep_pid" 2>/dev/null || true
if [ -f "$marker" ]; then
  fail "lock did not skip npm"
fi

if [ "$failures" -ne 0 ]; then
  echo "session-hooks tests failed" >&2
  exit 1
fi
echo "session-hooks fixture tests passed."
