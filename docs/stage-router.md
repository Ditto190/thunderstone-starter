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
| **Monitor** | Latest workflow run on the default branch failed (`gh run list`); or an open issue labeled `incident`, `regression`, or `p0` (GitHub only). |
| **Triage** | Dirty tree plus: `git diff --check` fails; diff matches secret/absolute-path patterns; `.state/tests-known-red` present; or changes under `.github/workflows/**`, `scripts/**`, `.husky/**`, or common lockfiles. Also: open PR with failing checks (even when the tree is clean). |
| **Build** | Dirty tree without triage signals; docs-only (`**/*.md`) edits; commits ahead of remote with no open PR; open PR approved with all checks green; clean synced **default branch** → suggest claiming a Project #2 item. |

When `gh` is missing or not authenticated, GitHub-backed signals are skipped (silent degrade).

## Enable

1. Ensure `.cursor/hooks.json` registers `.cursor/hooks/stage-router.sh` on `sessionStart`
   (`timeout`: 5, `failClosed`: false).
2. Keep the script executable (`git mode 100755`).
3. Optional: mark local test failures with an empty marker file `.state/tests-known-red` after a red `npm test`.

## Rollback

Delete `.cursor/hooks.json` (or remove the `sessionStart` entry). No repo mutations are performed by the hook.

## Runtime notes

- **Cursor Cloud Agents** do not run `sessionStart` today; use `stop` or `afterFileEdit` hooks there as a follow-up if you need the same advisory in cloud.
- **Self-hosted pool workers** do fire `sessionStart` like desktop Cursor.

## Safety

The script never commits, pushes, merges, or edits files. It does not use cron.
