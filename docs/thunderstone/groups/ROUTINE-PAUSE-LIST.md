# Routine pause list (2026-10-10; builds on ROUTINE-AUDIT.md)
Rule: no cron or time-based routines; checks are event-triggered (sessionStart hook + `health.sh --bg` at first work turn). Only DT's UI can pause; no automation was changed by this file. Paths: ~/agent-data/agents/<id>/automations/<name>.

| Bot | Routine (schedule) | Action |
|---|---|---|
| Chief of Staff (437fcfe8) | thunderstone-weekday-cli-health (08:15 wkdy), thunderstone-pm-cli-pulse (16:15 wkdy) | PAUSE both (bot retired); covered by health.sh |
| Chief Thunderstone (45e99bd6) | vm-morning-resume-doctor (08:20 wkdy) | CONVERT to event trigger: sessionStart hook / first-turn `health.sh --bg`; pause the routine |
| Chief Thunderstone | runner-terminal-smoke-brief (10:30 wkdy) | PAUSE; Runner smoke only as an on-demand brief |
| Chief Lorekeeper (e7b5b3b8) | lorekeeper-morning-context-health (08:25), lorekeeper-evening-registry-sync (16:45) | PAUSE; covered by health.sh; registry sync on demand when Chief briefs it |
| Chief Lorekeeper | lorekeeper-drive-freshness-pulse (15:00, never ran) | PAUSE; on-demand only |
| Git-Scout (08fb189f) | weekday-lean-git-status (16:30 wkdy) | PAUSE. health.sh only counts dirty files; it does not fail on a dirty tree, check remotes, or wake Scout. |
| Executive Assistant (f9067a3d) | weekly-investment-gmail-scan (Mon 08:00) | Approved exception: the only time-based routine still allowed, because DT asked to keep this scan. Do not add others. |
| Grok Bot (0ef89b8b) | own periodic routine not found on disk | CHECK routines UI; pause any time-based one |
| Lingxi's Engineer Bot (81e154c6) | 30-minute PR watch (profile text; no automation file on disk) | DISABLE cadence; GitHub-event or on-demand `gh pr list` via Chief brief; unknown if a server-side routine exists, check UI |
| Nightly Audit Engineer (08a36657) | 4am default (profile text; no automation file) | DISABLE; run only as a Runner brief on DT's request; check UI |
| Projects Manager (7b71c6ec) | none (empty automations dir) | none; no routine |
| Tradbot (4b5e2379), Researcher (38239e9c), Senior Developer (1761543b), Cursor-Runner (a087ceb3), dr eggbot (eaac08b1) | none on disk | none; do not create any |

Result: 8 weekday model runs/day -> 0 weekday routines; 1 weekly exception (EA investment scan, DT kept it).
Caveat: only on-disk automations were audited; server-side routines for bots without files: unknown.
