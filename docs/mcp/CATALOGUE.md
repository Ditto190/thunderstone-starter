# Catalogue MCP

The agent trees are not copied into this repo. They are served by the official Awesome Copilot MCP.

| Fact | Value |
|---|---|
| Server | `io.github.microsoft/awesome-copilot` |
| Image | `ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot:latest` |
| Tools | `search_instructions`, `load_instruction` |
| Prompt | `get_search_prompt` |
| Source repo | `github/awesome-copilot` |
| Shared public URL | none |

`modme-ui-01` `.github/agents` and `mcapp-ai-starter` `consolidated_sources/awesome-copilot` are local mirrors of that corpus. Use them only if the MCP is down. Do not commit either tree here.

## Start it

Bootstrap does not install Docker. On a machine that already has Docker:

```sh
bash scripts/awesome-copilot-mcp.sh
```

That runs the official image with `--http` and publishes it on loopback port 8080 only.
Cursor can then use `config/mcp/awesome-copilot.http.json`.
Copilot stdio mode, no port, is `config/mcp/awesome-copilot.stdio.json`.

Do not paste the loopback URL into grok.com. grok.com needs a public HTTPS host.
The Microsoft sample can be deployed to your own Azure Container Apps (`azd up` in that sample). That hostname is yours. This repo does not publish one.

xAI docs, separate from the catalogue, are `config/mcp/xai-docs.http.json` (`https://docs.x.ai/api/mcp`, no key).

## Pointers

`.github/agents/` names five roles. Each file tells the agent to `load_instruction` instead of inlining the upstream body.

| Pointer | Load |
|---|---|
| adr-generator | `adr-generator.agent.md` |
| se-system-architecture-reviewer | `se-system-architecture-reviewer.agent.md` |
| github-actions-expert | `github-actions-expert.agent.md` |
| se-security-reviewer | `se-security-reviewer.agent.md` |
| agent-governance-reviewer | `agent-governance-reviewer.agent.md` |

Refuse database, cache, Beast Mode, and product-framework agents in this repository.
