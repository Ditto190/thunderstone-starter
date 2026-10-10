# TASK-005 — Local checkpoint commit (DT approved)

From: CoS (DT said "Commit")
To: Chief Thunderstone → Git-Scout
Workspace: $WORKSPACE/thunderstone-starter
Branch: main @ e8a7624

## Approved scope
Local commit ONLY. No push, no remote, no GitHub create/PR.

## Dirty paths (as of CoS preflight)
- M `AGENTS.md` (+7 lines)
- ?? `.context/` (leanctx doctor/smoke outputs)
- ?? `.cursor/rules/` (`lean-ctx.mdc`)
- ?? `.cursorrules`
- ?? `AGENTS.md.bak`
- ?? `LEAN-CTX.md`

## Staging guidance (Scout decide with hygiene)
Prefer include: `AGENTS.md`, `LEAN-CTX.md`, `.cursorrules`, `.cursor/rules/`
Prefer exclude unless Scout finds value: `AGENTS.md.bak`, empty/noise under `.context/` (or add ignore rules instead of committing doctor dumps)
Never: secrets, real `.env`, credentials

## Proposed message
`chore: lean-ctx agent docs and cursor rules checkpoint`

## Evidence
Write `$WORKSPACE/thunderstone/artifacts/TASK005-local-checkpoint.md` with staged paths, hash, status --short, confirmation no push.

Report CoS when DONE.
