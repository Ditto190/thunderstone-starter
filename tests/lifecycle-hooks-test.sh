#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPATCHER="${ROOT}/.cursor/hooks/lifecycle.sh"
failures=0

fail() {
  echo "lifecycle test FAIL: $*" >&2
  failures=1
}

cursor_events='["sessionStart","sessionEnd","beforeSubmitPrompt","preToolUse","postToolUse","postToolUseFailure","subagentStart","subagentStop","preCompact","stop"]'
grok_events='["PermissionDenied","StopFailure","Notification","PostCompact"]'

registered="$(jq -c '[.hooks | keys[]] | sort' "${ROOT}/.cursor/hooks.json")"
expected="$(printf '%s' "$cursor_events" | jq -c 'sort')"
if [ "$registered" != "$expected" ]; then
  fail "cursor events registered=$registered expected=$expected"
fi

if jq -e '[.hooks[][] | .failClosed] | any(. != false)' "${ROOT}/.cursor/hooks.json" >/dev/null; then
  fail "a cursor hook is fail-closed"
fi

grok_registered="$(jq -c '[.hooks | keys[]] | sort' "${ROOT}/.grok/hooks/thunderstone.json")"
grok_expected="$(printf '%s' "$grok_events" | jq -c 'sort')"
if [ "$grok_registered" != "$grok_expected" ]; then
  fail "grok events registered=$grok_registered expected=$grok_expected"
fi

overlap="$(jq -n --argjson cursor "$(jq '.hooks | keys' "${ROOT}/.cursor/hooks.json")" \
  --argjson grok "$(jq '.hooks | keys' "${ROOT}/.grok/hooks/thunderstone.json")" \
  '[$cursor[]] - ([$cursor[]] - $grok) | length')"
if [ "$overlap" != "0" ]; then
  fail "cursor and grok hook names overlap"
fi

for event in sessionStart sessionEnd beforeSubmitPrompt preToolUse postToolUse postToolUseFailure subagentStart subagentStop preCompact stop permissionDenied stopFailure notification postCompact; do
  if ! jq -e --arg event "$event" '.hooks[$event] == true' "${ROOT}/.cursor/hooks/lifecycle.config.json" >/dev/null; then
    fail "config missing enabled $event"
  fi
done

for path in \
  .cursor/hooks/lifecycle.sh \
  .cursor/hooks/lifecycle.config.json \
  .cursor/hooks.json \
  .grok/hooks/thunderstone.json \
  .grok/config.toml \
  tests/lifecycle-hooks-test.sh \
  docs/HOOKS.md
do
  if git -C "$ROOT" check-ignore -q -- "$path"; then
    fail "gitignored $path"
  fi
done

mock="$(mktemp -d)"
trap 'rm -rf "$mock"' EXIT
cat >"${mock}/lean-ctx" <<'EOF'
#!/bin/sh
if [ "${LEAN_FAIL:-0}" = 1 ]; then
  exit 1
fi
cat >/dev/null
exit 0
EOF
chmod +x "${mock}/lean-ctx"

cat >"${mock}/router.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"additional_context":"STAGE=Build reason=test"}'
EOF
chmod +x "${mock}/router.sh"

trace="${mock}/trace"
run_dispatch() {
  local event="$1"
  local body="$2"
  (
    export LIFECYCLE_TRACE="$trace"
    export LIFECYCLE_LEAN_CTX_BIN="${mock}/lean-ctx"
    export LIFECYCLE_STAGE_ROUTER="${mock}/router.sh"
    if [ -n "${LIFECYCLE_CONFIG_OVERRIDE:-}" ]; then
      export LIFECYCLE_CONFIG="$LIFECYCLE_CONFIG_OVERRIDE"
    fi
    if [ -n "${LEAN_FAIL_OVERRIDE:-}" ]; then
      export LEAN_FAIL="$LEAN_FAIL_OVERRIDE"
    fi
    printf '%s' "$body" | bash "$DISPATCHER" "$event"
  )
}

out="$(run_dispatch sessionStart '{"hookEventName":"sessionStart"}')"
if [ "$out" != '{"additional_context":"STAGE=Build reason=test"}' ]; then
  fail "sessionStart router output: $out"
fi
if [ "$(paste -sd, "$trace")" != "lean-ctx,stage-router" ]; then
  fail "sessionStart order: $(paste -sd, "$trace")"
fi

: >"$trace"
end_out="$(run_dispatch sessionEnd '{"ok":true}')"
if [ "$end_out" != '{}' ]; then
  fail "sessionEnd output: $end_out"
fi
if [ "$(paste -sd, "$trace")" != "lean-ctx" ]; then
  fail "sessionEnd handlers: $(paste -sd, "$trace")"
fi

status=0
bad="$(run_dispatch preToolUse 'not-json')" || status=$?
if [ "$status" -ne 0 ] || [ "$bad" != '{}' ]; then
  fail "malformed payload status=$status out=$bad"
fi

status=0
fail_out="$(LEAN_FAIL_OVERRIDE=1 run_dispatch postToolUseFailure '{}')" || status=$?
if [ "$status" -ne 0 ] || [ "$fail_out" != '{}' ]; then
  fail "lean-ctx failure status=$status out=$fail_out"
fi

disabled="${mock}/config.json"
jq '.hooks.sessionStart = false' "${ROOT}/.cursor/hooks/lifecycle.config.json" >"$disabled"
: >"$trace"
disabled_out="$(LIFECYCLE_CONFIG_OVERRIDE="$disabled" run_dispatch sessionStart '{}')"
if [ "$disabled_out" != '{}' ] || [ -s "$trace" ]; then
  fail "disabled sessionStart out=$disabled_out trace=$(cat "$trace")"
fi

repo="$(mktemp -d)"
git -C "$repo" init -b main >/dev/null
git -C "$repo" config user.email "Ditto190@users.noreply.github.com"
git -C "$repo" config user.name "Ditto190"
echo seed >"${repo}/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -m "chore: seed" >/dev/null
real="$(cd "$repo" && LIFECYCLE_LEAN_CTX_BIN="${mock}/lean-ctx" bash "$DISPATCHER" sessionStart <<<'{}')"
if ! printf '%s' "$real" | jq -e . >/dev/null; then
  fail "real router JSON: $real"
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi
echo "lifecycle hooks tests passed."
