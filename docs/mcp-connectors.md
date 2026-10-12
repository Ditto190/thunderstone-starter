# MCP connectors (Thunderstone catalog)

Shared, secret-free catalogue for **Cursor**, **Grok Build / Grok CLI**, **Claude Code**, and **Grok Bot** VMs. Browser-sidecar MCP (agent-browser, Scrapling, local `firecrawl-mcp` via npx) stays in [`config/browser/mcp.example.json`](../config/browser/mcp.example.json). This catalog adds the four official **remote HTTP** connectors below.

## Catalogue

| Connector | URL | Auth | Transport |
| --- | --- | --- | --- |
| **xai-docs** | `https://docs.x.ai/api/mcp` | xAI account / session (provider-dependent) | Streamable HTTP |
| **context7** | `https://mcp.context7.com/mcp/oauth` | OAuth (optional `CONTEXT7_API_KEY` for higher limits in other clients) | Streamable HTTP |
| **github** | `https://api.githubcopilot.com/mcp/` | GitHub / Copilot OAuth | Streamable HTTP |
| **firecrawl** | `https://mcp.firecrawl.dev/v2/mcp-oauth` | Firecrawl OAuth | Streamable HTTP |

**Perplexity:** Perplexity Computer and in-chat tools are **not** configured through this file. Use Perplexity’s own connector UI or the stdio server with `PERPLEXITY_API_KEY` when you need MCP outside Perplexity chat. Do not duplicate Perplexity inside the Thunderstone HTTP catalog unless you add a separate, documented entry.

**Composio (optional):** Use [`https://connect.composio.dev/mcp`](https://connect.composio.dev/mcp) only for apps that **lack** an official MCP. Prefer the URLs in the table above when the vendor ships OAuth HTTP MCP.

Repo templates:

- Cursor-shaped JSON: [`config/mcp/thunderstone-mcp.example.json`](../config/mcp/thunderstone-mcp.example.json)
- Grok TOML: [`config/grok/mcp.catalog.toml.example`](../config/grok/mcp.catalog.toml.example)

---

## Cursor IDE and Cloud Agents

`.cursor/mcp.json` is **gitignored** (see [`.gitignore`](../.gitignore)). Never commit OAuth tokens or API keys.

**Merge the catalog into your checkout:**

```bash
bash scripts/install-cursor-mcp-catalog.sh
```

The script deep-merges `mcpServers` keys with `jq`: Thunderstone entries are added or updated; **unknown keys are never removed**.

Then authenticate each OAuth server:

- **Desktop:** Cursor **Settings → MCP**
- **Cloud Agents:** [Cursor dashboard](https://cursor.com/dashboard) → your agent environment → **Plugins & MCPs** (complete OAuth for context7, github, firecrawl as prompted)

Local browser MCP: copy or merge [`config/browser/mcp.example.json`](../config/browser/mcp.example.json) if you need the CloakBrowser sidecar and Scrapling stdio servers.

---

## Claude Code (project `.mcp.json`)

Claude reads project `.mcp.json` with the same `mcpServers` shape as Cursor. Example fragment (merge with your existing servers):

```json
{
  "mcpServers": {
    "xai-docs": { "url": "https://docs.x.ai/api/mcp" },
    "context7": { "url": "https://mcp.context7.com/mcp/oauth" },
    "github": { "url": "https://api.githubcopilot.com/mcp/" },
    "firecrawl": { "url": "https://mcp.firecrawl.dev/v2/mcp-oauth" }
  }
}
```

Complete OAuth in Claude’s MCP settings when each server is first used.

---

## Grok Build / Grok CLI

**Bootstrap (idempotent on a machine with `grok` on PATH):**

```bash
bash scripts/grok-mcp-bootstrap.sh
```

**Manual equivalents:**

```bash
grok mcp add --transport http xai-docs https://docs.x.ai/api/mcp
grok mcp add --transport http context7 https://mcp.context7.com/mcp/oauth
grok mcp add --transport http github https://api.githubcopilot.com/mcp/
grok mcp add --transport http firecrawl https://mcp.firecrawl.dev/v2/mcp-oauth
grok mcp doctor xai-docs
```

Use `--scope project` with `grok mcp add` to write **`.grok/config.toml`** in the repo, or copy [`config/grok/mcp.catalog.toml.example`](../config/grok/mcp.catalog.toml.example) into `.grok/config.toml`.

Grok also loads compatible entries from `.cursor/mcp.json` and `.mcp.json` at lower priority than `config.toml`; disable vendor import in Grok settings if you want TOML-only.

**Grok Bot VM:** Run bootstrap once per VM user after `scripts/bootstrap.sh`. OAuth opens in the desktop browser; tokens are stored under `~/.grok/mcp_credentials.json`, not in the repo.

---

## Verification prompt (paste into any MCP-capable client)

Run all four steps. Reply with **PASS** or **FAIL** per step and one line of evidence.

1. **Inventory** — List configured MCP servers (Cursor: Settings → MCP; Grok: `grok mcp list`; Claude: MCP panel). Confirm **xai-docs**, **context7**, **github**, and **firecrawl** appear.  
   - PASS / FAIL: ___

2. **xai-docs** — Ask the agent to use **xai-docs** to look up a current xAI API or Grok Build MCP fact (e.g. remote MCP `url` configuration).  
   - PASS / FAIL: ___

3. **context7** — Use **context7** to resolve library docs for a package you use (e.g. `react` or `next.js`) and cite one accurate detail from the returned docs.  
   - PASS / FAIL: ___

4. **github or firecrawl** — Use **github** to search or inspect a public repo you name, **or** use **firecrawl** to fetch a public HTTPS page title.  
   - PASS / FAIL: ___

If any step fails, finish OAuth for that connector and rerun `grok mcp doctor <name>` (Grok) or re-authenticate in Cursor/Claude before retrying.
