# Stage router (sessionStart advisory)

Prototype hook that inspects **read-only** git (and optional GitHub CLI) state at Cursor
`sessionStart` and prints a single JSON line advising **Monitor**, **Triage**, or **Build**.

## Output

| Condition | stdout |
|-----------|--------|
| No stage applies, or working tree clean with green default-branch CI | `{}` |
| Otherwise | `{"additional_context":"STAGE=<Monitor\|Triage\|Build> reason=..."}` |

Precedence: **Monitor** → **Triage** → **Build**.

## Signals

| Stage | Signals |
|-------|---------|
| **Monitor** | Latest workflow run on the default branch failed (`gh run list`); latest deployment status `failure` or `error` (`gh api` deployment statuses); or an open issue labeled `incident`, `regression`, or `p0` (GitHub only). |
| **Triage** | Dirty tree plus: `git diff --check` fails (tracked, staged, **and untracked** via `git diff --no-index`); working tree text matches secret/absolute-path patterns (includes untracked file contents); `.state/tests-known-red` present; or changes under `.github/workflows/**`, `scripts/**`, `.husky/**`, `.cursor/hooks/**`, or common lockfiles. Also: open PR with failing checks (even when the tree is clean). |
| **Build** | Dirty tree without triage signals; docs-only (`**/*.md`) edits; commits ahead of remote with no open PR; open PR approved with all checks green; clean synced **default branch** → suggest claiming a Project #2 item. |

Changed paths are collected with NUL-safe `git diff --name-only -z` plus untracked `git ls-files -o -z` so renames and spaces in paths work.

When `gh` is missing or not authenticated, GitHub-backed signals are skipped (silent degrade). Each `gh` call uses a short per-call timeout inside a total **~4s** budget so the hook stays within the 5s `sessionStart` limit.

## Enable

1. Ensure `.cursor/hooks.json` registers `.cursor/hooks/lifecycle.sh sessionStart` on `sessionStart`
   (`timeout`: 5, `failClosed`: false). The dispatcher calls `.cursor/hooks/stage-router.sh`.
2. Keep the script executable (`git mode 100755`).
3. Optional: mark local test failures with an empty marker file `.state/tests-known-red` after a red `npm test`.

## Rollback

Delete `.cursor/hooks.json` (or remove the `sessionStart` entry). No repo mutations are performed by the hook.

## Runtime notes

- **Cursor Cloud Agents** do not run `sessionStart` today; use `stop` or `afterFileEdit` hooks there as a follow-up if you need the same advisory in cloud.
- **Self-hosted pool workers** do fire `sessionStart` like desktop Cursor.
- **Agents Window:** Cursor may drop `sessionStart` `additional_context` on the first turn; use a `beforeSubmitPrompt` hook as a fallback if you need the stage hint before the first message.

## Safety

The script never commits, pushes, merges, or edits files. It does not use cron.
