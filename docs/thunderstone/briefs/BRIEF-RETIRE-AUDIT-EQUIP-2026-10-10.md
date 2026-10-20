# BRIEF — retire SWE/Eng Lead in groups, audit template, equip.sh (2026-10-10)

From: Chief Thunderstone (DT decisions via Grok Bot). Class C, files/branches only; NO stage/commit/push (Git-Scout commits/PRs, DT merges). Standing law: full auto-permission on the VM; third-party sends/posts/purchases still need approval. Don't touch PR #7 branch.

## Step A (do first, then message Chief so Git-Scout can start PR B)
1. GROUPS.md in $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/: mark SWE (cfbb15f3) and Engineering Lead (d298c7a0) RETIRED/merged into Lingxi's Engineer Bot (81e154c6); remove or mark their patch files accordingly; make sure Lingxi's Engineer Bot's row/patch is present and describes the merged event-triggered SDLC loop.
2. Create $WORKSPACE/thunderstone/briefs/TEMPLATE-AUDIT-AREA.md (replaces the Nightly Audit Engineer bot): one codebase area per run; map/signatures first (LeanCTX map or rg/fd, no full reads); output = evidence path + <=5 lines; code changes ONLY via a branch + PR through Git-Scout (DT merges); event-triggered, not cron; no secrets; stop conditions; fill-in fields (area, repo, scope, validation).
3. Refresh $WORKSPACE/wt-import/docs/thunderstone/ (copies + MANIFEST + README) to include the above; re-run hygiene, npm test, shellcheck, diff-check, secret/email/path scan. Message Chief: "PR B ready" with the manifest count.

## Step B — tool equipping (like modme-ui-01)
Study the pattern first (read-only): Ditto190/modme-ui-01 (checkout $WORKSPACE/modme-ui-01): scripts/, scripts/cursor-ai/, .cursor/, docs/agent-tech-guide.md; use Context7/official docs for each tool.
Build $WORKSPACE/thunderstone/scripts/equip.sh: idempotent, safe to re-run, silent when green (print only problems), `--check` prints a table: tool | installed | authed | bots/groups that use it.
Tools: gh, glab (if available), uvx/serena, npx context7, githits CLI (if one exists; verify, don't guess), lean-ctx, xAI docs MCP.
Actions: verify/install CLIs under ~/.local (no root), merge MCP entries into ~/.cursor/mcp.json (backup first, never overwrite existing entries, no secrets inline: env var names only), and provide CLI wrappers for Grok Bots where MCP tools aren't callable (bots cannot call lean-ctx ctx_* tools): e.g. $WORKSPACE/thunderstone/scripts/bin/ts-<tool> wrappers.
Validate: shellcheck, bash -n, run equip.sh twice (idempotent), `equip.sh --check`.

## Step C — standard block tool order
Required order: project files > Context7/xAI docs > GitHub > GitLab > Githits > Drive > Serena > web > computer-use. Fix it in STANDARD-PROFILE-BLOCK and list exactly which patch files in groups/ still have the old order (tinkabot and Lingxi's already correct). Fix the files you can (files only) and tell Chief which ones Grok Bot must apply.

Evidence: $WORKSPACE/thunderstone/artifacts/RETIRE-AUDIT-EQUIP-2026-10-10.md (paths, exit codes, --check table, patch list). Report to Chief, max 6 lines.
