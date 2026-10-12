#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIFE="${ROOT}/.cursor/hooks/lifecycle.sh"
failures=0

fail() {
  echo "lifecycle test FAIL: $1" >&2
  failures=1
}

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" != "$expected" ]; then
    echo "lifecycle test FAIL: $name" >&2
    echo "  expected: $expected" >&2
    echo "  got: $actual" >&2
    failures=1
  fi
}

cursor_events=(
  sessionStart
  sessionEnd
  beforeSubmitPrompt
  preToolUse
  postToolUse
  postToolUseFailure
  subagentStart
  subagentStop
  preCompact
  stop
)

for event in "${cursor_events[@]}"; do
  count="$(jq -r --arg e "$event" '.hooks[$e] | length' "${ROOT}/.cursor/hooks.json")"
  assert_eq "cursor ${event} count" "1" "$count"
  cmd="$(jq -r --arg e "$event" '.hooks[$e][0].command' "${ROOT}/.cursor/hooks.json")"
  case "$cmd" in
    ".cursor/hooks/lifecycle.sh ${event}") ;;
    *) fail "cursor ${event} command is ${cmd}" ;;
  esac
  closed="$(jq -r --arg e "$event" '.hooks[$e][0].failClosed' "${ROOT}/.cursor/hooks.json")"
  assert_eq "cursor ${event} failClosed" "false" "$closed"
done

grok_events=(PermissionDenied StopFailure StopCancelled PostCompact Notification)
for event in "${grok_events[@]}"; do
  count="$(jq -r --arg e "$event" '.hooks[$e] | length' "${ROOT}/.grok/hooks/thunderstone.json")"
  assert_eq "grok ${event} count" "1" "$count"
  cmd="$(jq -r --arg e "$event" '.hooks[$e][0].hooks[0].command' "${ROOT}/.grok/hooks/thunderstone.json")"
  case "$cmd" in
    "../../.cursor/hooks/lifecycle.sh ${event}") ;;
    *) fail "grok ${event} command is ${cmd}" ;;
  esac
  type_name="$(jq -r --arg e "$event" '.hooks[$e][0].hooks[0].type' "${ROOT}/.grok/hooks/thunderstone.json")"
  assert_eq "grok ${event} type" "command" "$type_name"
done

matcher="$(jq -r '.hooks.Notification[0].matcher' "${ROOT}/.grok/hooks/thunderstone.json")"
assert_eq "idle matcher" "idle_prompt" "$matcher"

if [ ! -x "$LIFE" ]; then
  fail "lifecycle.sh is not executable"
fi

out="$(printf 'not-json' | PATH="/usr/bin:/bin" bash "$LIFE" || true)"
status=0
printf 'not-json' | PATH="/usr/bin:/bin" bash "$LIFE" >/dev/null || status=$?
assert_eq "malformed exit" "0" "$status"
assert_eq "malformed stdout" "{}" "$out"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(
  cd "$tmp"
  git init -b main >/dev/null
  git config user.email "Ditto190@users.noreply.github.com"
  git config user.name "Ditto190"
  echo seed >README.md
  git add README.md
  git commit -m "chore: seed" >/dev/null
)
start_out="$(cd "$tmp" && printf '{}' | PATH="/usr/bin:/bin" bash "$LIFE" sessionStart)"
if ! printf '%s' "$start_out" | grep -q 'STAGE=Build'; then
  fail "sessionStart did not emit Build stage: ${start_out}"
fi
if ! printf '%s' "$start_out" | jq -e . >/dev/null; then
  fail "sessionStart output is not JSON"
fi

end_out="$(printf '{}' | PATH="/usr/bin:/bin" bash "$LIFE" sessionEnd)"
assert_eq "sessionEnd stdout" "{}" "$end_out"

python3 - <<PY
import hashlib, json, pathlib, sys
root = pathlib.Path("${ROOT}") / ".agents/skills/composio"
doc = json.loads((root / "PROVENANCE.json").read_text())
assert doc["commit"] == "f9ce49953598e13371c406ac346846696a4d8385"
assert doc["repository"] == "https://github.com/ComposioHQ/composio"
for rel, digest in doc["files"].items():
    got = hashlib.sha256((root / rel).read_bytes()).hexdigest()
    if got != digest:
        print(f"provenance mismatch {rel}", file=sys.stderr)
        sys.exit(1)
required = {"SKILL.md", "references/errors.md", "references/for-you.md", "references/platform.md"}
if set(doc["files"]) != required:
    print("provenance file set mismatch", file=sys.stderr)
    sys.exit(1)
PY

for rel in \
  .cursor/hooks/lifecycle.sh \
  .cursor/hooks/stage-router.sh \
  .cursor/hooks.json \
  .grok/hooks/thunderstone.json \
  .agents/skills/composio/SKILL.md \
  .agents/skills/composio/PROVENANCE.json \
  tests/lifecycle-test.sh \
  scripts/update-composio-skill.sh \
  config/mcp.example.json \
  docs/grok-cursor-kickoff.md
do
  if git -C "$ROOT" check-ignore -q -- "$rel"; then
    fail "gitignored: ${rel}"
  fi
done

while IFS= read -r cmd; do
  script="${cmd%% *}"
  resolved="$(cd "${ROOT}/.grok/hooks" && cd "$(dirname -- "$script")" && pwd)/$(basename -- "$script")"
  if [ ! -x "$resolved" ]; then
    fail "grok hook path does not resolve to an executable: ${cmd}"
  fi
done < <(jq -r '.hooks[][].hooks[0].command' "${ROOT}/.grok/hooks/thunderstone.json")

if grep -nE '/(home|Users|root)/' "$LIFE" >/dev/null; then
  fail "lifecycle.sh contains an absolute home path"
fi

if [ "$failures" -ne 0 ]; then
  echo "lifecycle tests failed" >&2
  exit 1
fi
echo "lifecycle fixture tests passed."
