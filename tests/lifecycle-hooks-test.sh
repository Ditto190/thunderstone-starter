#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIFECYCLE="${ROOT}/.cursor/hooks/lifecycle.sh"
HOOKS_JSON="${ROOT}/.cursor/hooks.json"
failures=0

fail() {
  echo "lifecycle test FAIL: $*" >&2
  failures=1
}

[ -x "$LIFECYCLE" ] || fail "lifecycle.sh not executable"

for event in sessionStart sessionEnd beforeSubmitPrompt preToolUse postToolUse postToolUseFailure subagentStart subagentStop preCompact stop; do
  if ! grep -q "\"$event\"" "$HOOKS_JSON"; then
    fail "hooks.json missing event $event"
  fi
  if ! grep -q "lifecycle.sh $event" "$HOOKS_JSON"; then
    fail "hooks.json does not route $event through lifecycle.sh"
  fi
done

out="$(printf '{}' | bash "$LIFECYCLE" sessionEnd 2>/dev/null || true)"
if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
  fail "sessionEnd must emit JSON (got: $out)"
fi

if ! grep -q stage-router.sh "$HOOKS_JSON"; then
  : # stage-router invoked from lifecycle sessionStart, not registered directly
fi

if [ ! -f "$ROOT/config/skills/vendored/composio/SKILL.md" ]; then
  fail "vendored composio skill missing"
fi
if [ ! -f "$ROOT/config/skills/vendored/composio/PROVENANCE.json" ]; then
  fail "composio provenance missing"
fi

if ! grep -q '^\.agents/skills/' "$ROOT/.gitignore" 2>/dev/null; then
  fail ".gitignore should ignore generated .agents/skills installs"
fi

bash "$ROOT/scripts/skills-install.sh" >/dev/null
if [ ! -f "$ROOT/.agents/skills/composio/SKILL.md" ]; then
  fail "skills-install did not copy vendored composio"
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi
echo "lifecycle hooks tests passed."
