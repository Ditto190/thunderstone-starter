#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
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
echo "collection-hooks-test passed"
