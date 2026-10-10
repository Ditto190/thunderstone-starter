#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
sh -n scripts/bootstrap.sh
for script in scripts/*.sh; do bash -n "$script"; done
for script in scripts/*.mjs; do node --check "$script"; done
node -e 'for (const f of ["package.json",".cursor/environment.json"]) JSON.parse(require("fs").readFileSync(f))'
bash scripts/check-hygiene.sh
command -v shellcheck >/dev/null || { echo "ShellCheck required"; exit 1; }
shellcheck scripts/*.sh
node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="thunderstone")process.exit(1)'
CLAN_NAME=override node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="override")process.exit(1)'
entry="$(bash scripts/changelog-entry.sh --from-json tests/fixtures/pr.json)"
grep -qF "(#7) [ci, security]" <<<"$entry"
test -f CHANGELOG.md
# run-task.sh static guard: lean-ctx off for the agent process only, --force, and the no-push/deploy/send prompt
run_task="$(grep -F 'exec ' scripts/run-task.sh)"
grep -qF 'LEAN_CTX_DISABLED=1 agent -p --force' <<<"$run_task"
grep -qF 'Do not push, deploy or send messages.' <<<"$run_task"
if grep -qE '^[[:space:]]*export[[:space:]]+LEAN_CTX_DISABLED' scripts/run-task.sh; then echo 'run-task.sh must not export LEAN_CTX_DISABLED'; exit 1; fi
echo "Infrastructure validation passed."
