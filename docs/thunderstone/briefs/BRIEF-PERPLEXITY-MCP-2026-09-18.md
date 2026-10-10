# BRIEF — Perplexity MCP connector path
Date: 2026-09-18 AEST
From: Chief Thunderstone → Cursor-Runner
Priority: DT explicit

## Objective
Read and parse `$WORKSPACE/notes/note.txt`. Produce a concrete plan + config stubs to add the official Perplexity API MCP connector for agents on this VM (Cursor / Grok Bot / shared workstation). Prefer remote hosted MCP.

## Non-goals
- Do NOT create/spend a Perplexity API key or ask DT to paste one in chat.
- Do NOT commit secrets. No `pplx-...` literals in git-tracked files.
- Do NOT push/git write unless DT approves later.
- Do NOT nest `agent`/`run-task.sh` if `CURSOR_AGENT=1` — do the CLI work yourself.

## Scope / acceptance
1. Summarize note: remote vs stdio vs HTTP; tools exposed; billing distinction.
2. Inspect current MCP config locations (read-only first): `~/.cursor/mcp.json`, project `.cursor/mcp.json` under `$WORKSPACE/thunderstone-starter` if any, Grok Bot MCP if discoverable.
3. Recommend **remote** config for Cursor:
   ```json
   "perplexity": { "url": "https://api.perplexity.ai/mcp", "headers": { "Authorization": "Bearer ${PERPLEXITY_API_KEY}" } }
   ```
   Note whether Cursor supports env interpolation; if not, document secret-request / env file path under Thunderstone env precedence (never print secrets).
4. Check if a Grok Bot / Cursor plugin exists (`SearchPlugins` / plugin cache) named Perplexity; if yes, document InstallPlugin path; if no, document AddMcpServer / manual mcp.json path.
5. Write artifact: `$WORKSPACE/reports/PERPLEXITY-MCP-PLAN-2026-09-18.md` with:
   - Decision (remote vs stdio)
   - Exact files to edit
   - Stub JSON with placeholders only
   - Steps for DT: create API key → provide via secret-request / env → enable
   - Validation commands (doctor / list tools) once key present
6. Optional: draft stub file at `$WORKSPACE/thunderstone/config/mcp-perplexity.stub.json` (placeholders only).

## Validation
- Artifact path exists; no real API keys in it.
- Report uses Thunderstone compact format at top.

## Report back to Chief
One Thunderstone report + artifact path only (USAGE CAP).
