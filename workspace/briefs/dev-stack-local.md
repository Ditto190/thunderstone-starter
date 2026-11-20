# Enable local-dev MCP stack + Dev Container

## Goal

Harden thunderstone-starter for a VM-primary local-dev loop with a portable Dev Container / Codespaces path, and wire Context7 plus Caveman Cloud via the existing mcp.example → gitignored `.cursor/mcp.json` pattern. Keep Origin, Composio, and Computer Use as product/plugin enablement (no duplicate mcp.json entries).

## Acceptance

- `.devcontainer/` boots Node 22+ tooling suitable for `npm test` / `doctor.sh` (Cursor CLI install skipped via `SKIP_CURSOR_INSTALL=1`).
- `config/dev-stack/mcp.example.json` configures Context7 (env-run + `CONTEXT7_API_KEY`) and Caveman Cloud remote MCP (OAuth URL template); no Composio/Origin/Computer Use servers in that file.
- `docs/dev-stack/LOCAL-DEV.md` documents VM primary, WSL probe notes, Dev Container, MCP duplicate policy, and Grok My Machines operator checklist.
- `.env.example` lists `CONTEXT7_API_KEY=` (name only).
- `AGENTS.md` and `docs/grok-vm/cursor-cloud-bridge.md` link the runbook.
- `npm test` / `scripts/validate.sh` stay green (JSON parse for new config files).
- Handoff receipts recorded; `handoff-receipt.sh check-promotion` allowed after verifier accept.
