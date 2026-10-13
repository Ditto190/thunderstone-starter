# Portable local VM agent workspace: plan (2026-10-11, Sydney)
Status: PLAN + scaffold only. Nothing installed beyond what is listed as present. No commit/push. Owner: Grok Bot (router); build: Chief Thunderstone -> Cursor-Runner; review: Engineering Lead + SWE; catalogue owner: dr eggbot. Board: Project #2 items #13, #15, #16, #17.

## Goals
1. Cursor cloud/headless agents (via `agent` CLI) test the catalogue method (drafts/AGENT-INDEX.draft.md, awesome-copilot style).
2. A very light, portable editor that can host Cursor + Grok bot agents.
3. Google Drive appears as a folder on the VM desktop (open in a file manager).
4. Architecture notes kept in `docs/plans/` (this dir) and mirrored to Drive 00_INBOX/Thunderstone.

## Facts verified now
- Present: `rclone` v1.60.1 (no remote configured, no ~/.config/rclone), `cursor`, `agent`, `tmux`, 107 GB free.
- Not present: `zed`, `code`, `fusermount` (so no FUSE mount yet), no google-drive-ocamlfuse.
- Hooks: feasibility in artifacts/HOOKS-FEASIBILITY-2026-10-10.md. Reliable in local CLI: sessionStart, sessionEnd, pre/postToolUse, before/afterShellExecution, afterFileEdit. `stop` is not emitted headless. Stages: analyse (in hook, sync) -> tests, report, CodeRabbit gate (detached tmux) -> CodeQL (CI only, read with gh) -> local commit proposal -> separate milestone push. Commit/push only with DT's exact approval via Git-Scout.
- Skills: only lean-ctx installed; caveman is a rules doc only (groups/CAVEMAN-RULES.md); grok-agent-ops, composio, skill-catalogue-retriever, obda-data-contract not found on the VM yet (source or confirm before use).

## Step plan (each a Runner brief, one at a time)
S1 Catalogue test via Cursor CLI: headless `agent` run (run-task.sh, detached tmux, LEAN_CTX_DISABLED=1, --trust only for the starter repo) reads AGENT-INDEX.draft.md and picks an owner for 5 sample tasks; compare with the first-match-wins rule. Blocker: Cursor usage limit seen earlier; if hit, stop and record, no retry. Success: 5/5 matches or listed diffs, evidence file.
S2 Editor: evaluate in this order, measure install size + idle RAM + start time, no installs beyond one candidate at a time:
   a. Zed: preferred for weight and its Agent Client Protocol (ACP) for external agents. UNVERIFIED: GPU/Vulkan need on this software-rendered desktop, and whether Cursor CLI exposes an ACP mode. Check `agent --help` and Zed Linux requirements first.
   b. code-server or VSCodium (heavier, but reliable in a browser/desktop with Cursor and Grok extensions).
   c. Cursor desktop AppImage as fallback.
   Success: one editor opens the starter repo root and can launch `agent` in its terminal.
S3 Drive on the desktop: needs DT's one-time Google sign-in for rclone (OAuth), done in DT's 1:1 chat, never a group. Then `rclone mount` if FUSE can be installed (needs `fuse3`), else a one-way `rclone copy`/`bisync` into ~/Drive triggered by events (session start/end), never cron. Scope to folders 00_INBOX/Thunderstone and 99_SYSTEM first; never 06_PRIVATE-RECORDS. Lorekeeper remains Drive owner.
S4 Hooks: Engineering Lead plan -> `.cursor/hooks.json` + `stage-runner-spawn.sh` on a branch from draft PR #8 (task #16).
S5 Docs: this plan + ARCH notes mirrored to Drive via Lorekeeper after DT's nod.

## Review path
Engineering Lead (SDLC loop, tracks #16), SWE (PR/diff review once code exists), Senior Developer only for architecture questions. Everything on branches; DT merges.

## Risks
Usage limit on the Cursor key; lean-ctx global preToolUse hooks shadow reads for headless agent (use LEAN_CTX_DISABLED=1 per process); Drive FUSE may be unavailable in this container; Zed may need a GPU.
