#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
sh -n scripts/bootstrap.sh
for script in scripts/*.sh; do bash -n "$script"; done
for script in scripts/*.mjs; do node --check "$script"; done
node -e 'for (const f of ["package.json",".cursor/environment.json",".cursor/hooks.json","config/mcp/servers.json","config/skills/manifest.json"]) JSON.parse(require("fs").readFileSync(f))'
bash scripts/check-hygiene.sh
bash scripts/skills-install.sh --check
node scripts/mcp-sync.mjs --check
# Profile gating: computer-use tools render for the VM profile only; output goes to a temp dir.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Caller's MCP_DISABLE/MCP_ENABLE must not change these profile assertions.
unset MCP_DISABLE MCP_ENABLE
PERPLEXITY_API_KEY=ci THUNDERSTONE_PROFILE=vm node scripts/mcp-sync.mjs --out-dir "$tmp" --surface grok >/dev/null
grep -q '^\[mcp_servers.computer-use\]' "$tmp/.grok/config.toml"
grep -q '^\[mcp_servers.perplexity\]' "$tmp/.grok/config.toml"
PERPLEXITY_API_KEY=ci THUNDERSTONE_PROFILE=dev node scripts/mcp-sync.mjs --out-dir "$tmp" --surface cursor >/dev/null
node -e 'const c=JSON.parse(require("fs").readFileSync(process.argv[1]));if(c.mcpServers["computer-use"]||!c.mcpServers.perplexity)process.exit(1)' "$tmp/.cursor/mcp.json"
command -v shellcheck >/dev/null || { echo "ShellCheck required"; exit 1; }
shellcheck scripts/*.sh .cursor/hooks/*.sh tests/*.sh
bash tests/stage-router-test.sh
bash tests/check-hygiene-identity-test.sh
bash tests/agent-connectors-test.sh
node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="thunderstone")process.exit(1)'
CLAN_NAME=override node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="override")process.exit(1)'
entry="$(bash scripts/changelog-entry.sh --from-json tests/fixtures/pr.json)"
grep -qF "(#7) [ci, security]" <<<"$entry"
test -f CHANGELOG.md
echo "Infrastructure validation passed."
