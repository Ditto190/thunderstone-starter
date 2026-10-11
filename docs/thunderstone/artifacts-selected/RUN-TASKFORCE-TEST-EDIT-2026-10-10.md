# RUN-TASKFORCE-TEST-EDIT — 2026-10-10
Worker: Cursor-Runner (Class C). Branch ci/run-task-force-lean-off @ fe0999e (PR #7 tip), tree was clean before.
Edited: scripts/validate.sh ONLY (the test lives there; `npm test` runs it). Agent NOT run; static checks only.

## Checks added (before the final echo)
1. exec line in scripts/run-task.sh contains `LEAN_CTX_DISABLED=1 agent -p --force`
2. same line still contains `Do not push, deploy or send messages.`
3. fails if run-task.sh exports LEAN_CTX_DISABLED (keeps it process-local)
(First draft used `! grep`, which shellcheck SC2251 flagged and which would not trip errexit; replaced with an if/exit 1.)

## Exit codes
shellcheck scripts/*.sh 0 | npm test 0 | doctor.sh 0 | git diff --check 0 | npm run lint 0
Mutation proof (temp copies, repo untouched): removing LEAN_CTX_DISABLED=1, removing --force, removing the no-push sentence, and adding an export each make the check FAIL.

## Diff
```diff
@@ -13,4 +13,9 @@ CLAN_NAME=override node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!==
 entry="$(bash scripts/changelog-entry.sh --from-json tests/fixtures/pr.json)"
 grep -qF "(#7) [ci, security]" <<<"$entry"
 test -f CHANGELOG.md
+# run-task.sh static guard: lean-ctx off for the agent process only, --force, and the no-push/deploy/send prompt
+run_task="$(grep -F 'exec ' scripts/run-task.sh)"
+grep -qF 'LEAN_CTX_DISABLED=1 agent -p --force' <<<"$run_task"
+grep -qF 'Do not push, deploy or send messages.' <<<"$run_task"
+if grep -qE '^[[:space:]]*export[[:space:]]+LEAN_CTX_DISABLED' scripts/run-task.sh; then echo 'run-task.sh must not export LEAN_CTX_DISABLED'; exit 1; fi
 echo "Infrastructure validation passed."
```

## State
`git status --short`: ` M scripts/validate.sh` (only). Nothing staged/committed/pushed.
