# Antigravity & Agent Guidelines (Thunderstone Starter)

This workspace integrates **Antigravity**, **Cursor Cloud Agents**, **Grok VM**, and **AG2 (AutoGen)**.

## Workspace Loading & Precedence
- **Rules Directory:** `.agents/rules/` contains environment-specific rules for Windows (`windows-powershell.md`), Linux (`linux-vm-bash.md`), Backend Architecture (`backend-standards.md`), and Developer Experience (`dx-standards.md`).
- **Core Clan Protocol:** Defined in `AGENTS.md` and `docs/adr-agent-collection-kpis.md`.
- **Working Memory on Disk:** Follows Manus-style persistent files (`task_plan.md`, `findings.md`, `progress.md`).
- **MCP Configuration:** Managed via `.agents/mcp_config.json` and `.cursor/mcp.json`.

## Quick Commands
- **Environment Diagnostics:**
  - Windows: `py workspace/scripts/clan_tool.py doctor`
  - Linux: `bash scripts/doctor.sh`
- **Validation Suite:** `npm test`
- **AG2 3-Agent Baseline Run:** `py workspace/scripts/ag2_clan_runner.py --task "<desc>" --handoff-id "<id>" --mock`
- **Check Promotion:** `py workspace/scripts/clan_tool.py check <handoff_id>`
