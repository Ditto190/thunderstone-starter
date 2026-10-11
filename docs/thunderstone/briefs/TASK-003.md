# TASK-003 — Git-Scout read-only Git-init readiness (post-M1)

From: Chief Thunderstone (routed from CoS)
To: Git-Scout
Review mode: READ-ONLY
Workspace: $WORKSPACE/thunderstone-starter
Persist: $WORKSPACE/thunderstone/artifacts/TASK-003-git-scout.md

## Objective
Assess whether the extracted Thunderstone starter is ready for local `git init` (recommendation only). Do NOT init, stage, commit, push, create repo, or alter files.

## Context
- M1 DONE: starter extracted; sha256 OK; resume OK
- M2 bootstrap HELD (DT skipped) — doctor gaps remain (zip/fzf/rclone/shellcheck/make; Node 20 <22)
- GitHub promo / git init still held until Scout + CoS gate
- Do NOT init Git on $WORKSPACE/thunderstone control plane

## Inspect
- repo root; branch; remotes; status (expect not-a-repo)
- tree inventory vs .gitignore / .env.example / secret exclusions
- workflows/hooks; package manifests; validation evidence available
- secret-risk scan (do not print values)
- Compare to TECH-READINESS: $WORKSPACE/thunderstone/reports/TECH-READINESS.md

## Return (Git-Scout report)
- Ready for git init: yes/no + why
- Proposed branch name + initial commit message (proposal only)
- Risks / unexpected files / doctor-gap impact on init timing
- Explicit human-approval list
- Persist full report under artifacts/

Reply to Chief Thunderstone only; then idle quiet.
