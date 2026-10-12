# MCP configuration

Remote (HTTP/OAuth) MCP servers live in `http-remote.example.json`. Browser-sidecar servers live in `../browser/mcp.example.json`.

## Quick setup

```bash
bash scripts/mcp-sync.sh
```

This writes `.cursor/mcp.json` (gitignored). Restart the Cursor agent or reload MCP after OAuth completes in the client.

## Server notes

| Server | URL | Auth |
|--------|-----|------|
| `xai-docs` | `https://docs.x.ai/api/mcp` | Usually none |
| `context7` | `https://mcp.context7.com/mcp/oauth` | OAuth; optional API key via Context7 dashboard for higher quota |
| `github` | `https://api.githubcopilot.com/mcp/` | GitHub/Copilot OAuth |
| `firecrawl` | `https://mcp.firecrawl.dev/v2/mcp-oauth` | Firecrawl OAuth |

### Avoid duplicate GitHub MCP

If the **GitHub** marketplace plugin is enabled (`plugin-github-github`), remove the `github` entry from `.cursor/mcp.json` so only one GitHub MCP is active.

### Firecrawl: HTTP vs local CLI

`mcp-sync.sh` prefers the HTTP `firecrawl` entry from `http-remote.example.json`. The browser bundle’s stdio `firecrawl` (`npx firecrawl-mcp` via `env-run`) is omitted when HTTP is present. For local API-key use without OAuth, copy only the `firecrawl` block from `../browser/mcp.example.json` instead.

## Cloud Agents

Team or user MCP settings may already expose some of these servers (for example `xai-docs` and `Context7`). Repo `mcp-sync.sh` keeps local Desktop/CLI config aligned with the committed examples; OAuth still happens in the Cursor UI when a server first connects.
