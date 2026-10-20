# Session hooks

Event-driven Cursor hooks only. No cron, timers, or loops.

| Event | Script | What it does |
| --- | --- | --- |
| `sessionStart` | `.cursor/hooks/stage-router.sh` | Existing stage advisory. Unchanged. |
| `sessionStart` | `.cursor/hooks/session-skills.sh` | Names caveman, lean-ctx, and grok-agent-ops when `SKILL.md` is found. |
| `sessionEnd` | `.cursor/hooks/session-end-ci.sh` | Detaches local `npm test` when the worktree fingerprint changes. |

Each `hooks.json` entry uses `"timeout": 5` and `"failClosed": false`. Scripts return immediately. `sessionEnd` prints `{}` and writes no stderr when the path is green.

## Skill lookup

Search order:

1. `$THUNDERSTONE_SKILLS_ROOT/<name>/SKILL.md` when that variable is set
2. `.cursor/skills/<name>/SKILL.md`
3. `~/.cursor/skills/<name>/SKILL.md`

Stdout is one JSON object: `{"additional_context":"Skills: ...; missing: ..."}`. If nothing is found and local CI is green, stdout is `{}`.

## Local CI

`sessionEnd` hashes `git status --porcelain` plus `HEAD` into `.state/session-ci/fingerprint`. A change starts `timeout ${SESSION_CI_TIMEOUT:-600} npm test` in the background (`setsid`, or `nohup` when `setsid` is absent). The runner writes `.state/session-ci/last.json` (`head`, `started`, `finished`, `exit`, `log`) and `last.log`.

Skip when the fingerprint is unchanged, `.state/session-ci/lock` holds a live pid, the directory is not a git repo, or `SESSION_CI_DISABLE=1`.

The next `sessionStart` appends `last local CI: FAIL (exit N, .state/session-ci/last.log)` only when `last.json` has `exit != 0`.

`.state/` is gitignored, which covers `.state/session-ci/`.

## What these hooks do not do

Hooks never commit, push, open a pull request, or call `agent` / CodeRabbit. `sessionStart` makes no network calls. Push stays with Git-Scout at milestones. That push runs GitHub CI (`ci.yml`, `codeql.yml`, CodeRabbit), including CodeQL and PR review.

## Dispatcher (opt-in)

`.cursor/hooks.json.example` points `sessionStart`, `stop`, `postToolUseFailure`, and `afterFileEdit` at `.cursor/hooks/dispatch.sh`. Copy that file over `.cursor/hooks.json` only when you want the dispatcher. The checked-in `.cursor/hooks.json` stays on the stage router, skill note, and session-end CI.

`dispatch.sh` reads stdin JSON with `node`, routes `hook_event_name`, and kills a handler that exceeds `HOOKS_BUDGET_SEC` (default 4). Malformed JSON, an unknown event, a timeout, or non-JSON handler output all print `{}` and exit 0. `failClosed` stays false. Green runs print `{}` and write no stderr.

| Event | Handler | Side effect |
| --- | --- | --- |
| `sessionStart` | `events/session-start.sh` | Calls the stage router and skill note, merges `additional_context`, and once per session may add `DRIFT bridge: N files` when both bridge trees exist and differ. |
| `stop` | `events/stop.sh` | If `state/active-brief` exists, writes a receipt stub once per session. Stdout stays `{}`. |
| `postToolUseFailure` | `events/tool-failure.sh` | Appends one redacted line to `.cursor/hooks/state/tool-failures.jsonl`. |
| `afterFileEdit` | `events/report-edit.sh` | Indexes a path under `reports/` or `workspace/reports/` in `.cursor/hooks/state/reports-index.md`. |

`.cursor/hooks/state/` is gitignored.

## Disable and rollback

- `SESSION_CI_DISABLE=1` skips the detached test.
- Remove the `session-skills.sh` or `session-end-ci.sh` entry from `.cursor/hooks.json`.
- Leave the `stage-router.sh` entry in place.
- To drop the dispatcher, restore the previous `.cursor/hooks.json` and leave `hooks.json.example` unused. No handler runs unless that example is copied into place.
