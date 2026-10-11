#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
sh -n scripts/bootstrap.sh
for script in scripts/*.sh; do bash -n "$script"; done
for script in scripts/*.mjs services/domain-analysis/*.mjs; do node --check "$script"; done
node --check api/http.js
node --check api/health.js
node --check api/v1/domain.js
node --check api/v1/analyze.js
node -e 'for (const f of ["package.json",".cursor/environment.json",".cursor/hooks.json","vercel.json","config/domain/roster.json","config/domain/stages.json","config/domain/doc-sources.json"]) JSON.parse(require("fs").readFileSync(f))'
node --test services/domain-analysis/analyze.test.mjs
bash scripts/check-hygiene.sh
command -v shellcheck >/dev/null || { echo "ShellCheck required"; exit 1; }
shellcheck scripts/*.sh .cursor/hooks/*.sh tests/*.sh
bash tests/stage-router-test.sh
node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="thunderstone")process.exit(1)'
CLAN_NAME=override node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="override")process.exit(1)'
entry="$(bash scripts/changelog-entry.sh --from-json tests/fixtures/pr.json)"
grep -qF "(#7) [ci, security]" <<<"$entry"
test -f CHANGELOG.md
echo "Infrastructure validation passed."
