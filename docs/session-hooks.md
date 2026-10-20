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

## Disable and rollback

- `SESSION_CI_DISABLE=1` skips the detached test.
- Remove the `session-skills.sh` or `session-end-ci.sh` entry from `.cursor/hooks.json`.
- Leave the `stage-router.sh` entry in place.
