# BRIEF — Finished session cleanup + local checkpoint (2026-09-25)

From: Chief Thunderstone
To: Cursor-Runner (Class C) then Git-Scout (Class D)
DT ask: code review, resolve errors, clean pipeline, stage+commit for finished session.
Skipped prior lean-ctx commit widgets → do NOT reopen; TASK-005 already at a2d6a8c.

## Repo
`$WORKSPACE/thunderstone-starter` on `main` @ `a2d6a8c`, no remote.
Current dirt (only): `?? .context/` (leanctx artifacts), `?? AGENTS.md.bak`
No modified tracked files.

## Cursor-Runner (do first)
1. `cd $WORKSPACE/thunderstone-starter`
2. Code/pipeline review: `bash scripts/doctor.sh`; `npm test` (validate.sh); `npm run lint` if shellcheck present; `npm run format:check`; note exit codes.
3. Cleanup (working tree only, no git write):
   - Append to `.gitignore` (keep existing entries): `.context/` and `*.bak`
   - Delete `AGENTS.md.bak` (redundant backup of committed AGENTS.md)
   - Leave `.context/` on disk or empty it — either OK; must stay untracked via ignore
4. Re-run doctor + validate after cleanup.
5. Evidence: `$WORKSPACE/thunderstone/artifacts/SESSION-FINISH-2026-09-25.md` with exits, paths changed, `git status --short` after edit, recommended commit paths/message.
6. Do NOT stage/commit/push. Report to Chief when evidence ready.

## Git-Scout (after Runner evidence)
Class D, DT-approved finished-session local commit (no push / no remote / no PR):
- Stage ONLY: `.gitignore`
- Message exact: `chore: ignore lean-ctx context dumps and bak backups`
- Reject if any other path staged; secret scan; `git diff --cached --check`
- husky/npm test must pass on commit
- Evidence under `$WORKSPACE/thunderstone/artifacts/` + short report to Chief
- STOP if anything beyond `.gitignore` appears dirty/staged

## Standing exclusions
Never commit `.context/`, `AGENTS.md.bak`, `.env`, secrets, `node_modules/`.
