#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
sh -n scripts/bootstrap.sh
for script in scripts/*.sh; do bash -n "$script"; done
for script in scripts/*.mjs; do node --check "$script"; done
node -e 'for (const f of ["package.json",".cursor/environment.json"]) JSON.parse(require("fs").readFileSync(f))'
command -v shellcheck >/dev/null || { echo "ShellCheck required"; exit 1; }
shellcheck scripts/*.sh
node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="thunderstone")process.exit(1)'
CLAN_NAME=override node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="override")process.exit(1)'
echo "Infrastructure validation passed."
