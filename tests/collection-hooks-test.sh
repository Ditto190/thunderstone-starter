#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
smoke_rel="tests/.hook-smoke-$$.sh"
smoke_abs="$REPO/$smoke_rel"
trap 'rm -f "$smoke_abs"; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.cursor/hooks"
cp "$REPO/.cursor/hooks/collection-metrics.mjs" "$tmp/.cursor/hooks/"
cp "$REPO/.cursor/hooks/handoff-duplicate-guard.mjs" "$tmp/.cursor/hooks/"
cd "$tmp"
STATE="${tmp}/.cursor/hooks/state"
mkdir -p "$STATE"
metrics="${STATE}/collection-metrics.jsonl"
launches="${STATE}/recent-launches.jsonl"
: >>"$metrics"
before="$(wc -l <"$metrics")"

node .cursor/hooks/collection-metrics.mjs <<'EOF' >/dev/null
{"hook_event_name":"subagentStop","status":"error"}
EOF
line="$(tail -n 1 "$metrics")"
jq -e '.status=="error" and (.ts_ms|tostring|length)==13' <<<"$line" >/dev/null

node .cursor/hooks/collection-metrics.mjs <<'EOF' >/dev/null
{"hook_event_name":"postToolUseFailure","failure_type":"timeout","timestamp_ms":1700000000000}
EOF
jq -e '.failure_type=="timeout" and .ts_ms==1700000000000' <<<"$(tail -n 1 "$metrics")" >/dev/null

printf '%s\n' '{"ts_ms":1,"key":"xabc:explore"}' >"$launches"
out="$(node .cursor/hooks/handoff-duplicate-guard.mjs <<'EOF'
{"subagent_type":"explore","handoff_id":"abc"}
EOF
)"
grep -q '"permission":"allow"' <<<"$out"
if tail -n 5 "$metrics" | grep -q 'abc:explore'; then
  echo "substring key matched a longer launch key"
  exit 1
fi

node .cursor/hooks/handoff-duplicate-guard.mjs >/dev/null <<'EOF'
{"subagent_type":"explore","handoff_id":"abc"}
EOF
dup="$(node .cursor/hooks/handoff-duplicate-guard.mjs <<'EOF'
{"subagent_type":"explore","handoff_id":"abc"}
EOF
)"
grep -q '"permission":"allow"' <<<"$dup"
tail -n 3 "$metrics" | grep -q '"launch_key":"abc:explore"'

after="$(wc -l <"$metrics")"
test "$after" -gt "$before"

# commit-gate: non-commit commands allow without hygiene
cd "$REPO"
nc_out="$(node .cursor/hooks/commit-gate.mjs <<'EOF'
{"command":"git status"}
EOF
)"
grep -q '"permission":"allow"' <<<"$nc_out"

# Prefer CURSOR_HOOK_BASH when present; non-zero exit => deny (not silent fail-open).
# Use /usr/bin/false (real executable) so Windows Node can CreateProcess it.
false_bin="/usr/bin/false"
test -x "$false_bin"
if command -v cygpath >/dev/null 2>&1; then
  false_bin="$(cygpath -w "$false_bin")"
fi
den_out="$(CURSOR_HOOK_BASH="$false_bin" node .cursor/hooks/commit-gate.mjs <<'EOF'
{"command":"ALLOW_LOCAL_COMMITS=1 true"}
EOF
)"
grep -q '"permission":"deny"' <<<"$den_out"

# run-hook resolves script from repoRoot, not cwd
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$smoke_abs"
mkdir -p "$tmp/elsewhere"
cd "$tmp/elsewhere"
node "$REPO/.cursor/hooks/run-hook.mjs" "$smoke_rel" </dev/null >/dev/null

echo "collection-hooks-test passed"
