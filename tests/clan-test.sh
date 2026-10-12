#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/bin" "$TMP/.cursor"
cp "$ROOT/scripts/clan.mjs" "$ROOT/scripts/clan-contract.mjs" "$ROOT/scripts/check-hygiene.sh" "$TMP/scripts/"
cat >"$TMP/bin/agent" <<'EOF'
#!/bin/sh
printf 'called\n' >>"${AGENT_STAMP:?}"
if [ "${AGENT_MODE:-ok}" = "empty" ]; then exit 0; fi
if [ "${AGENT_MODE:-ok}" = "fail" ]; then echo "nope" >&2; exit 1; fi
printf '%s\n' "outcome: ok"
EOF
cat >"$TMP/bin/rclone" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${RCLONE_LOG:?}"
exit 0
EOF
chmod +x "$TMP/bin/agent" "$TMP/bin/rclone"
cat >"$TMP/.cursor/mcp.json" <<'EOF'
{"mcpServers":{"perplexity":{"url":"https://api.perplexity.ai/mcp"}}}
EOF
export PATH="$TMP/bin:$PATH"
unset CURSOR_AGENT || true
export PERPLEXITY_API_KEY=test-key
export DRIVE_EXPORT_ROOT=00_INBOX/Thunderstone
export GDRIVE_REMOTE=gdrive
export RCLONE_LOG="$TMP/rclone.log"
export AGENT_STAMP="$TMP/agent.log"
cd "$TMP"
fail() { echo "clan-test FAIL: $*" >&2; exit 1; }
refuse() { if "$@"; then fail "expected refusal: $*"; fi; }

refuse node scripts/clan.mjs new TASK-003 --role chief-of-chiefs
node scripts/clan.mjs new TASK-010 --role cursor-hammer
node scripts/clan.mjs new TASK-010 --role cursor-hammer >/dev/null
refuse env CLAN_ENTRY=run-task CLAN_ACTIVE_ITEM=TASK-001 node scripts/clan.mjs run TASK-010
refuse env AGENT_MODE=empty CLAN_ENTRY=run-task node scripts/clan.mjs run TASK-010
node scripts/clan.mjs status TASK-010 --json | grep -q '"stage":"failed"' || fail "empty run did not fail"
rm -f workspace/items/TASK-010/report.md workspace/items/TASK-010/runs.jsonl
CLAN_ENTRY=run-task node scripts/clan.mjs run TASK-010
node scripts/clan.mjs status TASK-010 --json | grep -q '"stage":"reported"' || fail "stdout was not captured"
grep -q 'outcome: ok' workspace/items/TASK-010/report.md || fail "report body missing"
test ! -e .cursor/cli.json || fail "deny file left behind"
refuse env CLAN_ENTRY=export-drive node scripts/clan.mjs export TASK-010
mkdir -p workspace/items/TASK-010/export
ln -s /etc/hostname workspace/items/TASK-010/export/link
refuse env CLAN_ENTRY=export-drive node scripts/clan.mjs export TASK-010
rm workspace/items/TASK-010/export/link
printf '%s\n' "reviewed" > workspace/items/TASK-010/export/note.txt
CLAN_ENTRY=export-drive node scripts/clan.mjs export TASK-010
CLAN_ENTRY=export-drive node scripts/clan.mjs export TASK-010
test "$(wc -l <"$RCLONE_LOG")" -eq 1 || fail "export was not idempotent"
grep -q 'TASK-010/' "$RCLONE_LOG" || fail "export folder missing"
before="$(wc -l <"$AGENT_STAMP")"
CURSOR_AGENT=1 node scripts/clan.mjs new TASK-011 --role watcher-of-broken-things
CURSOR_AGENT=1 CLAN_ENTRY=run-task node scripts/clan.mjs run TASK-011
test "$(wc -l <"$AGENT_STAMP")" -eq "$before" || fail "in-session run spawned agent"
node scripts/clan.mjs status TASK-011 --json | grep -q '"stage":"running"' || fail "in-session run did not stay open"
printf '%s\n' "outcome: session" > workspace/items/TASK-011/report.md
node scripts/clan.mjs status TASK-011 --json | grep -q '"stage":"reported"' || fail "in-session report did not close"
echo "clan-test passed"
