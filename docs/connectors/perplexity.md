# Connector: Perplexity for Cursor, Grok and GrokBot agents

Status: PROPOSED (review required).

## What it gives agents
The official Perplexity MCP server exposes `perplexity_search` (ranked web results), `perplexity_ask`, `perplexity_reason` and `perplexity_research` (deep multi-source). It is web search and research only.

## What it does not give
Searching your own Perplexity chats is not covered. The server's tools are web-facing, and public sources describe thread history as a scroll-only Library without full-text search or a documented API. Treat chat search as unsupported until verified. Workable alternatives: export threads to Drive and search them there, or use a local indexer.

## Cursor (local, stdio)
`.cursor/mcp.json` runs the server via npx. The key is read from the environment, never stored in the repo. Set it in your shell or Cursor Cloud secrets. Per repo rules, do not auto-approve MCP tools.

## Grok API agents (remote)
xAI Remote MCP Tools connect from xAI's servers, so the endpoint must be public, Streamable HTTP or SSE, and send an authorization header. localhost does not work.
Design (unverified, test first):
1. Run the server in HTTP mode (`npm run start:http`, bound to 127.0.0.1).
2. Put an authenticated HTTPS proxy in front (for example a tunnel with access control).
3. Pass `server_url`, `server_label`, `authorization` and `allowed_tools` (start with `perplexity_search` only) in the Grok `tools` array.

## Grok CLI / GrokBot VM (local)
Use the same stdio command in the agent's MCP config on the VM. Keep the key in the VM's secret store.

## Guardrails
- Dedicated Perplexity API key with a spend limit; rotate on suspicion.
- Start read-only: search tools only, then add research tools.
- Treat returned web content as untrusted input.
- Never commit keys or paste them in chat.

## Smoke test
Ask the agent for one search with a recency filter and confirm sources are returned.
