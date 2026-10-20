# Routine audit (DRAFT 2026-10-10)
Found on disk: ~/agent-data/agents/<id>/automations/*/automation.json. All are model-run routines ("provenance untrusted"). Weekday schedules in Sydney time. No cron/systemd on the box (no `crontab`, no systemctl), so a "plain script" needs a scheduler: tmux loop started by resume.sh / XDG autostart, or one cheap Grok routine that only runs the script and speaks on failure.

| # | Owner | Routine | Cron | Last run | Problem | Recommend |
|---|---|---|---|---|---|---|
| 1 | CoS | thunderstone-weekday-cli-health | 15 8 * * 1-5 | never recorded | Same resume+doctor+git status as #4 | PAUSE (CoS hidden); replaced by script H |
| 2 | CoS | thunderstone-pm-cli-pulse | 15 16 * * 1-5 | never recorded (reports exist to 09 Oct) | git status + ls; duplicates #7 | PAUSE; fold into script H |
| 3 | Thunderstone | runner-terminal-smoke-brief | 30 10 * * 1-5 | ran | Briefs Runner (2 Grok turns) to run resume.sh, a third copy of the same check | PAUSE; script H covers |
| 4 | Thunderstone | vm-morning-resume-doctor | 20 8 * * 1-5 | ran | Fine content, but model run for a bash check | CONVERT to script H (wake Thunderstone only on non-zero) |
| 5 | Lorekeeper | lorekeeper-morning-context-health | 25 8 * * 1-5 | ran | file-exists checks | CONVERT into script H |
| 6 | Lorekeeper | lorekeeper-drive-freshness-pulse | 0 15 * * 1-5 | never | Needs Drive connector (model); low value daily | PAUSE; run on demand (or weekly) |
| 7 | Lorekeeper | lorekeeper-evening-registry-sync | 45 16 * * 1-5 | never | git status + mtime check | CONVERT into script H |
| 8 | Git-Scout | weekday-lean-git-status | 30 16 * * 1-5 | never | git status again (3rd copy) | PAUSE. health.sh records a dirty-file count and does not fail on it, does not check remotes, and does not wake Scout. Wake Scout from a brief when a human reads that count. |
| 9 | Executive Assistant | weekly-investment-gmail-scan | 0 8 * * 1 | ran (1 ok) | Needs Gmail (model) but weekly and wanted by DT | KEEP as the one approved time-based exception |

Result: 8 weekday model runs/day (~40/wk, mostly duplicates of one check) -> 1 script/day, 0 model runs when green.

## Script H (implemented as health.sh, not health-check.sh)
$WORKSPACE/thunderstone/scripts/health.sh: resume.sh, doctor.sh, `git status --short` counts for thunderstone-starter and modme-ui-01 (a dirty tree is a count in the log, not a failure), `gh auth status`, Cursor login. It does not check remotes and it does not wake Git-Scout. On failure it writes an artifact and exits non-zero; a caller may wake Chief Thunderstone. There is no scheduler.

## Other bots (no routines on disk for these; only profiles)
| Bot | Finding | Route heavy work |
|---|---|---|
| Lingxi's Engineer Bot | "watches PRs on a 30-minute cadence" + "launches cloud agents" = ~48 runs/day if enabled; spawns paid CloudAgents | PAUSE/disable cadence; replace with GitHub-event or daily `gh pr list` in script H; code jobs via Runner brief, not CloudAgent |
| Nightly Audit Engineer | Codebase-wide research + one cleanup per area at 4am; whole-repo model reading | PAUSE until needed; run as a Runner brief using Cursor CLI (`run-task.sh`), report path only |
| Projects Manager | Notion-based profile, but board is now GitHub Projects #2 (workflow thunderstone-github-project-ops); has an empty automations dir; briefed Thunderstone and re-read results | Point at GitHub board via `gh`; read-only; request work through Grok Bot->Thunderstone; no relaying |
| Tradbot | Email/calendar watcher; overlaps Executive Assistant; reported spawning its own background worker | No workers; merge into EA lane or restrict to personal email; no routine unless silent-when-green script |
| dr eggbot | Creates bots; woke itself for "Already covered" acknowledgement | Standard block (no acks); creations only on DT request |
| Grok Bot (me) | Own periodic routine not found on disk | Parent to check the routines UI and pause it |
| Executive Assistant | Profile says "proactively flag stale tasks"; encourages unprompted work | Add standard block; keep weekly scan only |

Also: AGENTS.md and vm-ops/ORCHESTRATION.md still name Chief of Chiefs / Thunder-Terminal / Cursor-Hammer / Watcher / Keeper, and "Chain DT -> CoS -> Thunder". Update both to the new chain.
