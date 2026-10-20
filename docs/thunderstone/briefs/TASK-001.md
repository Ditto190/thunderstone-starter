# TASK-001 — Thunderstone starter install/validate

From: Chief Thunderstone
To: Cursor-Runner
Workspace: $WORKSPACE/thunderstone-starter
Branch: not-yet-Git
Report out: $WORKSPACE/thunderstone/reports/TASK-001-status.md

## Objective
Install and validate the Thunderstone starter according to its Setup Guide.

## Preflight (Chief)
- `$WORKSPACE/thunderstone` exists (briefs/ + reports/).
- `$WORKSPACE/thunderstone-starter` was NOT present at dispatch time (no AGENTS.md, no scripts/).
- Confirm location yourself; if missing, stop and record explicit blocker (do not invent a Drive import unless this brief is amended).

## Scope
- Inspect any existing extracted starter at the workspace path.
- Run only documented safe bootstrap / resume / doctor steps from the starter itself.
- Record actual commands, exit codes, installed/missing tools, blockers.
- Write status report to `$WORKSPACE/thunderstone/reports/TASK-001-status.md`.

## Non-goals / hard stops
- Do NOT initialize Git, create a GitHub repo, upload to Drive, or change system-wide settings beyond approved starter scripts.
- Do NOT print or expose env values, secrets, tokens, cookies.
- Do NOT overwrite blindly if a partial tree appears.
- No recursive paid Cursor agents; use `~/.local/bin/thunder-agent` only if this brief later asks for Cursor CLI work (not required for TASK-001).

## Acceptance
- Starter location confirmed (or missing blocker explicit).
- Bootstrap result recorded (or N/A with reason).
- Resume/doctor output summarized without secrets.
- Privilege / OAuth / missing-tool blockers explicit.
- Status file written under `$WORKSPACE/thunderstone/reports/`.
- Confirm no GitHub/Drive write occurred.

## Return to Chief
Changed files, commands + exit codes, results, blockers, and the confirmation above — Thunderstone report format.
