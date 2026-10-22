#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
sh -n scripts/bootstrap.sh
for script in scripts/*.sh; do bash -n "$script"; done
for script in scripts/*.mjs; do node --check "$script"; done
node -e 'for (const f of ["package.json",".cursor/environment.json",".cursor/hooks.json","config/dev-stack/mcp.example.json","config/browser/mcp.example.json",".devcontainer/devcontainer.json"]) JSON.parse(require("fs").readFileSync(f))'
bash scripts/check-hygiene.sh
command -v shellcheck >/dev/null || { echo "ShellCheck required"; exit 1; }
shellcheck scripts/*.sh .cursor/hooks/*.sh tests/*.sh
bash tests/stage-router-test.sh
bash tests/check-hygiene-identity-test.sh
bash tests/run-task-usage-limit-test.sh
bash tests/run-task-guard-test.sh
bash tests/thunderstone-workspace-test.sh
CURSOR_WORKER_NAME=grok-shared \
CURSOR_WORKER_SESSION="thunderstone-worker-test-$$" \
CURSOR_WORKER_DIR="$PWD" \
CURSOR_WORKER_AUTOSTART=0 \
  bash tests/cursor-worker-test.sh
node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="thunderstone")process.exit(1)'
CLAN_NAME=override node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="override")process.exit(1)'
entry="$(bash scripts/changelog-entry.sh --from-json tests/fixtures/pr.json)"
grep -qF "(#7) [ci, security]" <<<"$entry"
test -f CHANGELOG.md
if [[ -f tests/agent-collection-invariants.sh ]]; then
  bash tests/agent-collection-invariants.sh
fi
bash tests/validate-brief-test.sh
bash tests/collection-hooks-test.sh
echo "Infrastructure validation passed."
