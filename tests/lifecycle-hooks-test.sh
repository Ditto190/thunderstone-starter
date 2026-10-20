#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIFECYCLE="${ROOT}/.cursor/hooks/lifecycle.sh"
CURSOR_HOOKS="${ROOT}/.cursor/hooks.json"
GROK_HOOKS="${ROOT}/.grok/hooks/lifecycle.json"
failures=0

# Report the failure message in $1 to stderr and set the global failures flag to 1.
# Return success so remaining checks run; the final flag check exits with failure.
fail() {
  echo "lifecycle test FAIL: $1" >&2
  failures=1
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

grok_events=(
  PermissionDenied
  StopFailure
  StopCancelled
  PostCompact
  Notification
)

for event in "${cursor_events[@]}"; do
  count="$(jq -r --arg e "$event" '.hooks[$e] | length' "$CURSOR_HOOKS")"
  if [ "$count" != "1" ]; then
    fail "cursor $event registration count is $count"
  fi
  cmd="$(jq -r --arg e "$event" '.hooks[$e][0].command' "$CURSOR_HOOKS")"
  case "$cmd" in
    ".cursor/hooks/lifecycle.sh $event") ;;
    *) fail "cursor $event command is [$cmd]" ;;
  esac
  closed="$(jq -r --arg e "$event" '.hooks[$e][0].failClosed' "$CURSOR_HOOKS")"
  if [ "$closed" != "false" ]; then
    fail "cursor $event failClosed is $closed"
  fi
done

for event in "${grok_events[@]}"; do
  count="$(jq -r --arg e "$event" '.hooks[$e] | length' "$GROK_HOOKS")"
  if [ "$count" != "1" ]; then
    fail "grok $event registration count is $count"
  fi
  cmd="$(jq -r --arg e "$event" '.hooks[$e][0].hooks[0].command' "$GROK_HOOKS")"
  case "$cmd" in
    ".cursor/hooks/lifecycle.sh $event") ;;
    *) fail "grok $event command is [$cmd]" ;;
  esac
  # Grok runs hook commands from the checkout root, same as Cursor.
  script="${cmd%% *}"
  if [ ! -f "${ROOT}/${script}" ]; then
    fail "grok $event command does not resolve from checkout root ($script)"
  fi
done

if [ "$(jq -r '.hooks.Notification[0].matcher' "$GROK_HOOKS")" != "idle_prompt" ]; then
  fail "Notification matcher is not idle_prompt"
fi

for event in "${cursor_events[@]}" "${grok_events[@]}"; do
  out="$(printf '' | bash "$LIFECYCLE" "$event")"
  if [ "$out" != "{}" ]; then
    # sessionStart on this dirty developer tree may return a stage advisory.
    if [ "$event" != "sessionStart" ] && [ "$event" != "SessionStart" ]; then
      fail "$event expected {} got $out"
    fi
  fi
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    fail "$event emitted invalid JSON: $out"
  fi
done

out="$(printf 'not-json' | bash "$LIFECYCLE" preToolUse)"
if [ "$out" != "{}" ]; then
  fail "malformed payload did not fail open: $out"
fi

out="$(printf '%s' '{"hook_event_name":"preToolUse","tool_name":"Shell"}' | bash "$LIFECYCLE")"
if [ "$out" != "{}" ]; then
  fail "stdin event without argv did not return {}: $out"
fi

mock_bin="$(mktemp -d)"
trap 'rm -rf "$mock_bin"' EXIT
cat >"${mock_bin}/lean-ctx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" != "hook" ] || [ "${2:-}" != "observe" ]; then
  echo "unexpected lean-ctx args: $*" >&2
  exit 3
fi
cat >/dev/null
EOF
cat >"${mock_bin}/timeout" <<'EOF'
#!/usr/bin/env bash
shift
"$@"
EOF
chmod +x "${mock_bin}/lean-ctx" "${mock_bin}/timeout"
if ! printf '%s' '{"hook_event_name":"stop"}' | PATH="${mock_bin}:${PATH}" bash "$LIFECYCLE" stop >/dev/null; then
  fail "lean-ctx observe path failed"
fi

# Missing lean-ctx still exits 0.
if ! printf 'not-json' | PATH="/usr/bin:/bin" bash "$LIFECYCLE" stop >/dev/null; then
  fail "missing lean-ctx did not fail open"
fi

# sessionStart delegates to the stage router inside a fixture repo.
fixture="$(mktemp -d)"
(
  cd "$fixture"
  git init -q -b main
  git config user.email "Ditto190@users.noreply.github.com"
  git config user.name "Ditto190"
  echo seed >README.md
  git add README.md
  git commit -qm "chore: seed"
  echo notes >notes.txt
)
out="$(cd "$fixture" && printf '%s' '{"session_id":"s"}' | bash "$LIFECYCLE" sessionStart)"
rm -rf "$fixture"
if ! printf '%s' "$out" | grep -q 'STAGE=Build'; then
  fail "sessionStart did not delegate to stage router: $out"
fi

# Sequence: start, tool, compact, stop, end.
for event in sessionEnd preToolUse preCompact stop sessionEnd; do
  out="$(printf '%s' "{\"hook_event_name\":\"$event\"}" | bash "$LIFECYCLE" "$event")"
  if [ "$out" != "{}" ]; then
    fail "sequence $event got $out"
  fi
done

for path in \
  .cursor/hooks/lifecycle.sh \
  .cursor/hooks/stage-router.sh \
  .cursor/hooks.json \
  .grok/hooks/lifecycle.json \
  .agents/skills/composio/SKILL.md \
  .agents/skills/composio/PROVENANCE.json
do
  if git -C "$ROOT" check-ignore -q -- "$path"; then
    fail "$path is gitignored"
  fi
done

if ! git -C "$ROOT" check-ignore -q -- .cursor/mcp.json; then
  fail ".cursor/mcp.json should stay gitignored"
fi

if [ "$failures" -ne 0 ]; then
  echo "lifecycle hook tests failed" >&2
  exit 1
fi
echo "lifecycle hook tests passed."
