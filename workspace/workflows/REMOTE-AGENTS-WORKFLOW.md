# Remote agents workflow

Public MCP URL: `https://grok-bot-vm-347906125.tail6c4b90.ts.net/mcp` (Tailscale Funnel → `http://127.0.0.1:3847/mcp`). Auth is a per-client bearer. Hashes live in `~/.config/thunderstone-bridge/tokens.json`. Plaintext is `~/.config/thunderstone-bridge/tokens/<name>.token` mode 0600. Do not print those files.

## Cursor cloud agent

`agent --help` (this host) has no cloud-launch or background-agent flag. It does have `agent worker` (self-hosted Cloud Agent worker / My Machines or Enterprise pool). Hosted Cloud Agents are started from Cursor or via Grok Bot, not from `scripts/run-task.sh`. tmux session `cursor-cloud` may already be present; do not recreate it from this workflow.

## Cursor CLI remote run

```bash
bash $THUNDERSTONE_ROOT/scripts/remote-agents.sh cli /absolute/path/brief.md
```

That execs `scripts/run-task.sh`. The starter invokes `agent -p` without `--trust` or `--force`. This host’s CLI supports both. Preferred invocation when DT asks for a full-auto remote run: `agent -p --trust --force` with the brief prompt. Do not spawn a nested CLI from inside an agent that was already told not to.

## Status and clients

```bash
bash $THUNDERSTONE_ROOT/scripts/remote-agents.sh status
bash $THUNDERSTONE_ROOT/scripts/remote-agents.sh add-client <name>
bash $THUNDERSTONE_ROOT/scripts/remote-agents.sh revoke-client <name>
```

`add-client` / `revoke-client` rewrite `tokens.json` and restart only the `bridge` tmux pane. Copy the token file to the client out of band. Names match `^[a-z0-9][a-z0-9._-]{0,63}$`. Built-in ids: grok-bot, cursor, chatgpt, claude, perplexity.

## ChatGPT web

Settings → Security and login → Developer mode. Then ChatGPT Plugins → plus → Add custom MCP server. Server URL is the Funnel `/mcp` URL. Transport: streaming HTTP (or SSE).

OpenAI docs (https://developers.openai.com/api/docs/guides/developer-mode and https://developers.openai.com/api/docs/guides/custom-mcp-server, checked 2026-10-16): authentication is **OAuth**, **No authentication**, or **mixed** (OAuth and no auth). There is no static bearer / API-key header field. OAuth access tokens are sent as `Authorization: Bearer …` after an OAuth 2.1 code+PKCE flow (https://developers.openai.com/plugins/build/auth). **Fit: no.** A pre-shared bridge bearer cannot be pasted in. Gap: an OAuth authorization server in front of the bridge, or a different client. Do not turn auth off on the public Funnel.

## Claude

Claude custom connector: Settings → Connectors → Add custom connector, URL = Funnel `/mcp`. Anthropic’s remote connector path is OAuth for authenticated MCP. **Fit: gap.** The bridge does not speak OAuth. A static bearer is not the documented Claude web connector auth.

## Perplexity

Custom remote connector. URL = Funnel `/mcp`. Transport Streamable HTTP. Auth **API Key**, which Perplexity sends as `Authorization: Bearer <key>`. **Fit: yes.** Paste the contents of `tokens/perplexity.token` into the API key field. OAuth is available and not required.
