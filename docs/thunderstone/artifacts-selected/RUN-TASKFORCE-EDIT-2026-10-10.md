# RUN-TASKFORCE-EDIT — 2026-10-10 (Step 1)
Worker: Cursor-Runner (Class C). Brief: $WORKSPACE/thunderstone/briefs/BRIEF-RUN-TASKFORCE-2026-10-10.md
Repo: $WORKSPACE/thunderstone-starter; remote origin = https://github.com/Ditto190/thunderstone-starter.git
Pre: branch main @ 4429619, `git status --short` empty (no dirt).
Action: `git switch -c ci/run-task-force-lean-off main` (local branch only). Edited scripts/run-task.sh only.

## Diff
```
-exec agent -p "Read AGENTS.md and the task brief at $brief. ... Do not push, deploy or send messages."
+exec env LEAN_CTX_DISABLED=1 agent -p --force "Read AGENTS.md and the task brief at $brief. ... Do not push, deploy or send messages."
```
(prompt text unchanged; env var set for the agent process only via `exec env`, not exported by the script.)

## Validation (exit codes)
shellcheck scripts/run-task.sh 0 | npm test 0 (hygiene + infrastructure passed) | bash scripts/doctor.sh 0 | git diff --check 0 | npm run lint 0

## State after
Branch ci/run-task-force-lean-off; `git status --short`: ` M scripts/run-task.sh` (only). Nothing staged/committed/pushed.

## Risk note
`--force` lets the headless agent run any shell command unless explicitly denied; the prompt's no-push/deploy/send rule is the only guard besides the repo's gh auth. Keep briefs bounded; Git-Scout/DT remain the push gate.
Commit/push/PR: not performed.
