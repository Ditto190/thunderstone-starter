# BRIEF — run-task.sh: LEAN_CTX_DISABLED=1 + --force (2026-10-10)

From: Chief Thunderstone (DT explicit yes via Grok Bot)
Flow: Runner (edit, Class C) -> Git-Scout (review/commit/push branch/PR, Class D) -> Runner (one bounded real test) -> Chief reports PR link + checks + test result to Grok Bot.

## Step 1 — Cursor-Runner (Class C)
Repo $WORKSPACE/thunderstone-starter. CURSOR_AGENT=1: no nested agent / run-task.sh while editing.
1. Confirm pwd, remotes, branch, `git status --short`. If the tree has unrelated dirt, STOP and report.
2. Create local branch `ci/run-task-force-lean-off` from main (branch creation only; NO commit, NO push).
3. Edit `scripts/run-task.sh` ONLY: the agent process runs with `LEAN_CTX_DISABLED=1` set for that process only (inline env prefix on the agent invocation, not exported to the wider script/shell) and with `--force`. KEEP the existing prompt text that forbids push/deploy/send unchanged.
4. Validate: shellcheck, `npm test`, `bash scripts/doctor.sh`, `git diff --check`. Show `git diff`.
5. Evidence: $WORKSPACE/thunderstone/artifacts/RUN-TASKFORCE-EDIT-2026-10-10.md (commands, exits, diff). Report to Chief; do not stage/commit/push.

## Step 2 — Git-Scout (Class D; briefed by Chief after Step 1)
Review diff (only scripts/run-task.sh), secret scan, `git diff --cached --check`; stage that one path; commit as Ditto190 noreply identity (match repo's identity-hygiene CI); push branch `ci/run-task-force-lean-off` ONLY; open PR to main; NO merge, DT merges. Report PR link + check status.

## Step 3 — Cursor-Runner (after PR exists)
Run ONE real bounded task via the branch's `scripts/run-task.sh`: a brief that makes a tiny harmless change in workspace/reports and runs a shell command to prove the shell tool works. Valid = exit 0 + refreshed file + shell command output captured. No retries beyond one. Do not leave anything staged/committed. Evidence: $WORKSPACE/thunderstone/artifacts/RUN-TASKFORCE-TEST-2026-10-10.md.
