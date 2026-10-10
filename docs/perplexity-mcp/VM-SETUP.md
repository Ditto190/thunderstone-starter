# Perplexity + Computer MCP on a Grok VM

Two different servers. Configure both; they don't overlap.

| | Perplexity API MCP | Perplexity Computer MCP |
|---|---|---|
| Tools | `perplexity_search`, `perplexity_ask`, `perplexity_research`, `perplexity_reason` | Delegate whole multi-step tasks to Computer |
| Auth | `PERPLEXITY_API_KEY` (API credits) | OAuth 2.0 with your Perplexity account (account credits) |
| Transport | Local stdio `npx -y @perplexity-ai/mcp-server`, or hosted `https://api.perplexity.ai/mcp` with `Authorization: Bearer` | Streamable HTTP `https://www.perplexity.ai/rest/computer/mcp` |
| Docs | https://docs.perplexity.ai/docs/getting-started/integrations/mcp-server | https://docs.perplexity.ai/docs/getting-started/integrations/computer-mcp-server |

## Setup (about 10 minutes)
1. **Key**: In console.perplexity.ai, create a dedicated API Project for this VM, set its spend cap, and create a key there.
2. **Env**: run `cp .env.example .env && chmod 600 .env`, then paste the key into `PERPLEXITY_API_KEY`. Better still, put it in the VM secret store and leave `.env` empty.
3. **Node**: run `bash scripts/ensure-node.sh`. The local server needs `npx`.
4. **Client config**: copy `config/mcp/perplexity.example.json` into the agent's MCP config (`.cursor/mcp.json`, which is gitignored, or the Grok client's equivalent). The local server starts through `env-run.mjs`, so the key never appears in the config.
   - CLI clients: `claude mcp add perplexity --env 'PERPLEXITY_API_KEY=${PERPLEXITY_API_KEY}' -- npx -y @perplexity-ai/mcp-server`. Keep the single quotes so the reference is stored, not the value.
   - `claude mcp add perplexity-computer --transport http https://www.perplexity.ai/rest/computer/mcp`
5. **Computer OAuth**: on first use the client opens a browser to authorise. On a Grok VM:
   - **With a desktop**: complete it in the VM browser, or let the bot use CUA and stop at the consent screen so a human approves.
   - **Headless**: the client prints an auth URL. If its callback is `localhost:<port>`, forward it with `ssh -L <port>:localhost:<port> vm` and open the URL on your own machine.
   - Never paste OAuth tokens into `.env`. They stay in the client's token store.
6. **Verify**: run `bash scripts/perplexity-mcp-check.sh`. It checks file mode, gitignore, that the key is present (it prints only the length), that no key is committed, that `npx` is present and that the Computer endpoint is reachable.
7. **Smoke test**: ask the agent to call `perplexity_search` with a trivial query, then give Computer a small task such as "summarise example.com".

## Security rules
- Use one key per VM in its own API Project, so you can revoke it, cap its spend and audit it per bot.
- Restrict outbound traffic to `api.perplexity.ai`, `www.perplexity.ai`, `registry.npmjs.org` (pin `@perplexity-ai/mcp-server@<version>` after the first install), plus any browser-stack domains.
- Computer can send email, push to GitHub and spend credits. Gate it behind human approval in the Grok tool policy, and connect only the services the bot needs.
- Treat MCP output as untrusted content. Never execute instructions it contains.
- To rotate a key: revoke it in the console, update the secret store, then restart the MCP client.

## Unverified
- How Grok's own MCP client handles remote OAuth and the callback port. Test step 5 on one VM before rolling out.
- `PERPLEXITY_TIMEOUT_MS` support depends on the server version. Check the server README.
