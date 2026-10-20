# BRIEF — changelog + import $WORKSPACE/thunderstone material + MCP availability survey (2026-10-10)

From: Chief Thunderstone (DT via Grok Bot). Standing law: full auto-permission on the VM; outbound third-party sends/posts/purchases still need approval.
State at brief time: PR #7 (ci/run-task-force-lean-off) OPEN, mergeStateStatus clean, NOT merged -> the real bounded Cursor test task WAITS for the merge. Starter is on main @ 4429619, clean.
Repo is PUBLIC: nothing sensitive may be imported (no keys/tokens, no personal data, no absolute home paths where hygiene forbids; run scripts/check-hygiene.sh and secret-scan; no staging zips; no state/ files).

## Cursor-Runner (Class C; Shell; use Cursor CLI `agent -p --force` with LEAN_CTX_DISABLED=1 for the agent process where it helps, else plain Shell). NO stage/commit/push (Git-Scout does Class D).
Work in SEPARATE git worktrees (e.g. $WORKSPACE/wt-changelog, $WORKSPACE/wt-import) from main so PR #7's branch and the main checkout are untouched.

### Task 1 — changelog entry (worktree branch `docs/changelog-roster-health-runtask`)
Use `scripts/changelog-entry.sh` (read its usage; follow repo conventions) to add an entry in CHANGELOG.md covering: roster/groups consolidation, event-triggered health.sh/startup.sh + sessionStart hook (no cron), run-task.sh --force + LEAN_CTX_DISABLED (PR #7, pending merge), browser stack availability, standing-law line. Keep it concise and factual. Run shellcheck/npm test/doctor/hygiene. Evidence diff.

### Task 2 — import material (worktree branch `docs/thunderstone-ops-import`)
Copy into the repo under `docs/thunderstone/` (policies/, briefs/, scripts/, groups/, artifacts-selected/, hooks/): 
- $WORKSPACE/thunderstone/policies (incl. consolidation-20261010/groups), briefs, scripts (health.sh, startup.sh, etc.)
- selected artifacts only: the evidence files from 2026-10-10 (CONSOLIDATION-BUILD, HEALTH-EVENT-TRIGGER, ROSTER-GROUPS-APPLY, STANDING-LAW-AUTOPERM, BROWSER-STACK-AVAILABILITY, BROWSER-USERS, PM-BOARD-RESEARCH, RUN-TASKFORCE-*, SECRETS-SCAN). Skip anything with tokens, emails, personal data, staging zips, state/ files.
- sanitised copy of ~/.cursor/hooks.json as docs/thunderstone/hooks/hooks.json.example (names/paths only, no secrets).
- README index at docs/thunderstone/README.md listing each item and its source path.
Before finishing run a secret scan (gitleaks if present else regex), scripts/check-hygiene.sh, npm test, shellcheck; write a manifest of exact paths for Git-Scout review. Do NOT include redundant or oversized files (>200KB).

### Task 3 — MCP/tool availability survey (read-only)
Verify (do not guess) what each is and whether present: LeanCTX, Caveman/cavecrew, "pstack" (find what it is: search ~/.cursor, ~/.config, npm/pip, docs; say "not found" if absent), Serena, GitHub MCP, GitLab MCP, Githits, Context7. Then, per bot group in $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/GROUPS.md, determine which bots have access (from ~/.cursor/mcp.json, each agent's ~/agent-data/agents/<id>/settings.json, plugin dirs). Table: tool x group (yes/no/unknown) + bots lacking access + how to add. Unknowns labelled unknown.

Evidence: $WORKSPACE/thunderstone/artifacts/COMMIT-CHANGELOG-IMPORT-2026-10-10.md (worktree paths, branches, diffs summary, manifests, exit codes, survey table). Report to Chief, max 5 lines.
