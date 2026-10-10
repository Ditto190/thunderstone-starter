# Give Perplexity search to Grok, Grok Bot and Cursor

Targets: Grok Build CLI, Grok Bot (VM), Cursor. This does not configure Perplexity Computer or Comet.

The `perplexity` server exposes `perplexity_search`, `perplexity_ask`, `perplexity_research` and `perplexity_reason` (verified against `@perplexity-ai/mcp-server` 1.3.0). It is wired in `config/mcp/servers.json` and rendered for both clients.

## Steps

1. Create an API key in the Perplexity API console (API Keys, Generate).
2. Store it where MCP launches can read it, on the machine that runs the agent:
   ```sh
   mkdir -p ~/.config/thunderstone && chmod 700 ~/.config/thunderstone
   (umask 077; printf 'PERPLEXITY_API_KEY=%s\n' "$PERPLEXITY_API_KEY" >> ~/.config/thunderstone/env)
   ```
   Paste the key into your shell variable first; never into a file in the repo.
3. Render the configs: `bash scripts/agent-setup.sh --sync`. The output must list `perplexity` under `enabled`.
4. Verify:
   - Grok Build or Grok Bot: start `grok` in the repo, run `grok mcp doctor` and check `perplexity` is connected, then ask it to use `perplexity_search`.
   - Cursor: Settings, Tools and MCP, confirm `perplexity` shows four tools. Restart Cursor after the first render.

## Alternative: hosted server with OAuth

Use this if you prefer not to keep a key on the machine. Add to `~/.grok/config.toml` or Cursor's user `mcp.json`:

```toml
[mcp_servers.perplexity-hosted]
url = "https://api.perplexity.ai/mcp"
```

Complete the OAuth prompt in the browser on first use. For headless runs, add `headers = { Authorization = "Bearer ${PERPLEXITY_API_KEY}" }` and export the variable in the process that launches Grok.

## Optional: delegate whole tasks to Perplexity Computer

Add `perplexity-computer` to `MCP_ENABLE` and sync. It points at `https://www.perplexity.ai/rest/computer/mcp`, uses OAuth, and spends Perplexity credits, so it stays off by default.

## Troubleshooting

- Server missing from the list: the sync prints `skipped: perplexity (missing PERPLEXITY_API_KEY)`. Fix the env file and rerun `--sync`.
- Works in a terminal but not in Cursor: Cursor does not inherit your shell. The generated config already launches through `scripts/env-run.mjs`, so keep the key in `~/.config/thunderstone/env`.
