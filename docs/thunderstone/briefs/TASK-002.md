# TASK-002 — Read-only Git readiness review (pre Git init / GitHub promotion)

From: Chief Thunderstone (routed from CoS / DT)
To: Git-Scout
Review mode: READ-ONLY
Persist report: $WORKSPACE/thunderstone/artifacts/TASK-002-git-scout.md

## Objective
Review current Thunderstone starter changes before possible local Git init and GitHub promotion.

## Hard stops (do not)
- Do NOT stage, commit, push, create repo, create PR, modify Drive, or alter files.
- Do NOT print secret values.

## Likely workspaces (verify first)
1. `$WORKSPACE/thunderstone-starter` — preferred starter tree
2. `$WORKSPACE/thunderstone` — control plane (briefs/reports/artifacts)

Chief preflight at dispatch:
- `$WORKSPACE/thunderstone-starter` was MISSING
- `$WORKSPACE/thunderstone` exists (briefs, reports, artifacts); no `.git`
- TASK-001 still blocked pending DT Drive-import approval

If starter missing: inspect what exists under `$WORKSPACE/thunderstone`, state explicitly that Git init of starter is blocked until extract, and still produce a read-only readiness report for the control-plane tree vs starter.

## Inspect
- repo root + branch; remotes; `git status --short`
- changed paths + diff stats; `git diff --check`
- `.gitignore` and env exclusions
- workflow/hook config
- likely secret-bearing files
- validation evidence already available (e.g. `$WORKSPACE/thunderstone/reports/TASK-001-status.md`)

## Return (Git-Scout report format + extras)
- Exact changed paths
- Risks and unexpected files
- Whether ready for Git init (yes/no + why)
- Proposed branch name + initial commit message (proposal only)
- Separate explicit list of actions needing human approval
- Persist full report under `$WORKSPACE/thunderstone/artifacts/TASK-002-git-scout.md`
- Reply to Chief Thunderstone only (idle quiet after)

## Acceptance
- Report file written
- No file mutations, no Git writes, no Drive writes
- Approval-needed actions listed separately and clearly
