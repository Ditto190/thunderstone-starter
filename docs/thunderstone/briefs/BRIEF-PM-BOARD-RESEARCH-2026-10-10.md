# BRIEF — Read-only research for Projects Manager board (2026-10-10)

From: Chief Thunderstone (on behalf of Projects Manager 7b71c6ec, DT-requested)
To: Cursor-Runner (Class C, Shell, headless). CURSOR_AGENT=1: no nested agent/run-task.sh.
HARD LIMITS: read-only. No pushes, no installs on shared repos, no repo/project mutations, no secrets printed. Use `gh` (read), WebFetch/curl, Context7/official GitHub docs. Keep it cost-efficient (README + docs + schema skims, not full clones; shallow clone to /tmp only if needed).

Context: GitHub Project v2 board https://github.com/users/Ditto190/projects/2 (linked to Ditto190/thunderstone-starter). Status = Not started / In progress / Blocked / Done / Archived; text fields Bot (claiming agent), Note; items are issues with emoji-prefixed titles. Planned: Actions workflow (PR for DT review) to add issues/PRs to project, set In progress on PR open, Done on merge/close, project-scoped token in repo secret.

## Q1 — how these agent-oriented trackers model claim / status / blocked / dependency flows
- https://github.com/gastownhall/beads
- https://github.com/Dicklesworthstone/beads_viewer
- https://github.com/Dicklesworthstone/beads_rust
- https://github.com/mantoni/beads-ui
- https://github.com/dolthub/dolt  and  https://github.com/dolthub/doltlite
Per tool: data model, statuses, claim/assign semantics, dependency/blocked-by types, ready-work query, export format, how multi-agent concurrency is handled.

## Q2 — public references for GitHub Projects v2 + Actions automation for multi-agent work
add-to-project (actions/add-to-project), status sync, token/permission approach (classic PAT vs fine-grained vs GitHub App; project scope; org vs user project limits), field updates via GraphQL (updateProjectV2ItemFieldValue; single-select option ids), built-in project workflows vs Actions. Cite official docs URLs.

## Q3 — gaps/recommendations for the board/skill/workflow
Cover: dependencies / blocked-by (GitHub issue dependencies / sub-issues vs custom field), claim locking so two bots cannot take the same item (what GitHub offers; assignee-as-lock, compare-and-set patterns, label/field race risks), agent-readable export (gh project item-list --format json / GraphQL snapshot), and verdict: is a beads/Dolt layer worth adding vs plain GitHub Projects (cost, complexity, fit with "GitHub is canonical for code-tied work").

## Output
Evidence file: $WORKSPACE/thunderstone/artifacts/PM-BOARD-RESEARCH-2026-10-10.md — concise: findings per Q (with source URLs), then a ranked recommended-changes list (max 8), assumptions and any thing not verified. Then report to Chief with path + 5-bullet summary. Commit/push/PR: not performed.
