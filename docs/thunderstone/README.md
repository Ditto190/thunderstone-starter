# Thunderstone VM operations: imported material (2026-10-10)

Snapshot of the operations policies, briefs, health scripts and selected evidence from the
Thunderstone VM working folder. `$WORKSPACE` is the VM workspace root and `~` is the VM user's
home; both were substituted for absolute paths so the public hygiene check passes.

Sanitisation applied to every copied file: absolute home and workspace paths replaced, email
addresses replaced with `DT`, agent UUIDs shortened to their first 8 characters, and the hyphen after `TASK` removed in the names `TASKFORCE` and `TASK005-local-checkpoint`
(the hygiene `generic-api-key` rule false-positives on `sk-` inside the originals). Scripts keep working
defaults through `WORKSPACE_ROOT` (default is the VM workspace root). Nothing under `state/`, logs,
backups, exports or staging was imported. See `MANIFEST.txt` for exact paths and sizes.

## Index (path in this folder, then source)


### Policies (roster, routing, standard profile block, routine audit)

- `policies/CHIEF-ORCHESTRATION.md`  <-  `$WORKSPACE/thunderstone/policies/CHIEF-ORCHESTRATION.md`
- `policies/ENGINEERING-MCP-POLICY.md`  <-  `$WORKSPACE/thunderstone/policies/ENGINEERING-MCP-POLICY.md`
- `policies/consolidation-20261010/LOREKEEPER-ON-DEMAND.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/LOREKEEPER-ON-DEMAND.md`
- `policies/consolidation-20261010/NEW-PRIMARY-DESCRIPTION.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/NEW-PRIMARY-DESCRIPTION.md`
- `policies/consolidation-20261010/NEW-THUNDERSTONE-ADDENDUM.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/NEW-THUNDERSTONE-ADDENDUM.md`
- `policies/consolidation-20261010/ROSTER-AND-ROUTING.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/ROSTER-AND-ROUTING.md`
- `policies/consolidation-20261010/ROUTINE-AUDIT.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/ROUTINE-AUDIT.md`
- `policies/consolidation-20261010/STANDARD-PROFILE-BLOCK.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/STANDARD-PROFILE-BLOCK.md`

### Groups (per-bot patches, caveman rules, routine pause list)

- `groups/CAVEMAN-RULES.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/CAVEMAN-RULES.md`
- `groups/DREGGBOT-GUIDE.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/DREGGBOT-GUIDE.md`
- `groups/GROUPS.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/GROUPS.md`
- `groups/MARKETPLACE-MAP.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/MARKETPLACE-MAP.md`
- `groups/ROUTINE-PAUSE-LIST.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/ROUTINE-PAUSE-LIST.md`
- `groups/STANDARD-PROFILE-BLOCK-SHORT.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/STANDARD-PROFILE-BLOCK-SHORT.md`
- `groups/chief-lorekeeper.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/chief-lorekeeper.patch.md`
- `groups/chief-of-staff.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/chief-of-staff.patch.md`
- `groups/chief-thunderstone.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/chief-thunderstone.patch.md`
- `groups/cursor-runner.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/cursor-runner.patch.md`
- `groups/dr-eggbot.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/dr-eggbot.patch.md`
- `groups/executive-assistant.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/executive-assistant.patch.md`
- `groups/git-scout.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/git-scout.patch.md`
- `groups/grok-bot.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/grok-bot.patch.md`
- `groups/lingxis-engineer-bot.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/lingxis-engineer-bot.patch.md`
- `groups/nightly-audit-engineer.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/nightly-audit-engineer.patch.md`
- `groups/projects-manager.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/projects-manager.patch.md`
- `groups/researcher.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/researcher.patch.md`
- `groups/senior-developer.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/senior-developer.patch.md`
- `groups/swe.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/swe.patch.md`
- `groups/tinkabot.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/tinkabot.patch.md`
- `groups/engineering-lead.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/engineering-lead.patch.md`
- `groups/tradbot.patch.md`  <-  `$WORKSPACE/thunderstone/policies/consolidation-20261010/groups/tradbot.patch.md`

### Briefs

- `briefs/BRIEF-COMMIT-CHANGELOG-IMPORT-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-COMMIT-CHANGELOG-IMPORT-2026-10-10.md`
- `briefs/BRIEF-CONSOLIDATION-BUILD-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-CONSOLIDATION-BUILD-2026-10-10.md`
- `briefs/BRIEF-CURSOR-CLI-SMOKE-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-CURSOR-CLI-SMOKE-2026-10-10.md`
- `briefs/BRIEF-DOCTOR-TOOLS-2026-09-30.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-DOCTOR-TOOLS-2026-09-30.md`
- `briefs/BRIEF-GIT-SCOUT-LEANCTX-CHECKPOINT-2026-09-18.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-GIT-SCOUT-LEANCTX-CHECKPOINT-2026-09-18.md`
- `briefs/BRIEF-HEALTH-EVENT-TRIGGER-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-HEALTH-EVENT-TRIGGER-2026-10-10.md`
- `briefs/BRIEF-PERPLEXITY-MCP-2026-09-18.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-PERPLEXITY-MCP-2026-09-18.md`
- `briefs/BRIEF-PM-BOARD-RESEARCH-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-PM-BOARD-RESEARCH-2026-10-10.md`
- `briefs/BRIEF-ROSTER-GROUPS-APPLY-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-ROSTER-GROUPS-APPLY-2026-10-10.md`
- `briefs/BRIEF-ROUTINES-ROLES-2026-09-18.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-ROUTINES-ROLES-2026-09-18.md`
- `briefs/BRIEF-RUN-TASKFORCE-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUN-TASKFORCE-2026-10-10.md` (source name has a hyphen after TASK)
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-23.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-23.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-24.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-24.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-25.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-25.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-28.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-28.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-29.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-29.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-30.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-09-30.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-10-01.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-10-01.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-10-02.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-2026-10-02.md`
- `briefs/BRIEF-RUNNER-TERMINAL-SMOKE-ROUTINE-2026-09-18.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RUNNER-TERMINAL-SMOKE-ROUTINE-2026-09-18.md`
- `briefs/BRIEF-SESSION-FINISH-2026-09-25.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-SESSION-FINISH-2026-09-25.md`
- `briefs/BRIEF-STANDING-LAW-AUTOPERM-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-STANDING-LAW-AUTOPERM-2026-10-10.md`
- `briefs/BRIEF-STANDING-ORCHESTRATION-2026-09-18.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-STANDING-ORCHESTRATION-2026-09-18.md`
- `briefs/TASK-001.md`  <-  `$WORKSPACE/thunderstone/briefs/TASK-001.md`
- `briefs/TASK-002.md`  <-  `$WORKSPACE/thunderstone/briefs/TASK-002.md`
- `briefs/TASK-003.md`  <-  `$WORKSPACE/thunderstone/briefs/TASK-003.md`
- `briefs/TASK-004.md`  <-  `$WORKSPACE/thunderstone/briefs/TASK-004.md`
- `briefs/TASK005-local-checkpoint.md`  <-  `$WORKSPACE/thunderstone/briefs/TASK005-local-checkpoint.md` (source name has a hyphen after TASK)
- `briefs/BRIEF-RETIRE-AUDIT-EQUIP-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/briefs/BRIEF-RETIRE-AUDIT-EQUIP-2026-10-10.md`
- `briefs/TEMPLATE-AUDIT-AREA.md`  <-  `$WORKSPACE/thunderstone/briefs/TEMPLATE-AUDIT-AREA.md`

### Scripts (event-triggered health check, startup, tests)

- `scripts/health.sh`  <-  `$WORKSPACE/thunderstone/scripts/health.sh`
- `scripts/startup.sh`  <-  `$WORKSPACE/thunderstone/scripts/startup.sh`
- `scripts/tests/health-test.sh`  <-  `$WORKSPACE/thunderstone/scripts/tests/health-test.sh`

### Selected 2026-10-10 evidence

- `artifacts-selected/BROWSER-STACK-AVAILABILITY-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/BROWSER-STACK-AVAILABILITY-2026-10-10.md`
- `artifacts-selected/BROWSER-USERS-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/BROWSER-USERS-2026-10-10.md`
- `artifacts-selected/CONSOLIDATION-BUILD-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/CONSOLIDATION-BUILD-2026-10-10.md`
- `artifacts-selected/HEALTH-EVENT-TRIGGER-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/HEALTH-EVENT-TRIGGER-2026-10-10.md`
- `artifacts-selected/PM-BOARD-RESEARCH-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/PM-BOARD-RESEARCH-2026-10-10.md`
- `artifacts-selected/ROSTER-GROUPS-APPLY-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/ROSTER-GROUPS-APPLY-2026-10-10.md`
- `artifacts-selected/ROSTER-GROUPS-PARTB-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/ROSTER-GROUPS-PARTB-2026-10-10.md`
- `artifacts-selected/RUN-TASKFORCE-EDIT-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/RUN-TASKFORCE-EDIT-2026-10-10.md` (source name has a hyphen after TASK)
- `artifacts-selected/RUN-TASKFORCE-TEST-EDIT-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/RUN-TASKFORCE-TEST-EDIT-2026-10-10.md` (source name has a hyphen after TASK)
- `artifacts-selected/SECRETS-SCAN-thunderstone-starter-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/SECRETS-SCAN-thunderstone-starter-2026-10-10.md`
- `artifacts-selected/STANDING-LAW-AUTOPERM-2026-10-10.md`  <-  `$WORKSPACE/thunderstone/artifacts/STANDING-LAW-AUTOPERM-2026-10-10.md`

### Hooks

- `hooks/hooks.json.example`  <-  `~/.cursor/hooks.json (sanitised)`

## Not imported
- `policies/agent-desc-updates/*.json`: full agent profile descriptions with internal agent ids; redundant with the group patches.
- `scripts/leanctx-export-drive.sh`: references a Drive folder id and a Drive sync remote.
- Other artifacts (CURSOR-CLI-SMOKE, PR*-GIT-SCOUT, README-FORCE-FIX), logs, `leanctx-export-*`, backups, `state/`, `staging/`, `reports/`, `config/`.

## Notes
- `hooks/hooks.json.example` keeps the structure and event names of the live hooks file. Copy it to
  `~/.cursor/hooks.json` and replace `$HOME` and `$WORKSPACE_ROOT` with real paths; Cursor does not expand them.
- The health check is event-triggered (`sessionStart`, `failClosed: false`, 5 s timeout). No cron, timers or routines.
