# TASK-004 — Approved local git init + first commit

From: Chief Thunderstone (CoS/DT second gate APPROVED)
To: Git-Scout
Workspace: $WORKSPACE/thunderstone-starter

## Exact approved scope (execute after read-first verify)
1. `git init` if not already a repo
2. Stage only starter paths consistent with Scout hygiene / `.gitignore` (no secrets)
3. First local commit message EXACTLY:
   `chore: initial Thunderstone VM starter import (v1.0.0)`
4. Report commit hash + `git status --short` after

## NOT approved
- push, remote add, GitHub create, PR, force
- `git add -A` / `git add .` if it would include secrets or ignore-violations
- Prefer explicit path staging over blanket add

## Evidence
Persist: `$WORKSPACE/thunderstone/artifacts/TASK-004-git-init-commit.md`
Include: commands + exit codes, staged path list, commit hash, status --short, confirmation no push/remote.

## Prior
- TASK-003: ready-for-git-init=yes (hygiene)
- M2 complete: doctor green, Node 22

Reply to Chief Thunderstone when DONE; then idle quiet.
