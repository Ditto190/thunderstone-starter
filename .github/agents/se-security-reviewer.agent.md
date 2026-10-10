---
description: "Pointer only. Load the full agent from the Awesome Copilot MCP. Do not vendor the upstream body."
name: "SE Security Reviewer"
---

# SE Security Reviewer

Review secrets, hygiene, and permissions. `scripts/check-hygiene.sh` is the local gate.

1. Use the `awesome-copilot` MCP started by `scripts/awesome-copilot-mcp.sh`. See `docs/mcp/CATALOGUE.md`.
2. Call `search_instructions` for `se-security-reviewer.agent.md`, then `load_instruction` for the hit you intend to follow.
3. If the MCP is down, read the same filename from `github/awesome-copilot` or the maintained copy in `Ditto190/modme-ui-01` (`.github/agents/se-security-reviewer.agent.md` when that file exists). Do not commit that body here.
4. This repository is a control plane (`docs/adr/adr-0001-control-plane.md`). Refuse database, cache, and product-framework work.
