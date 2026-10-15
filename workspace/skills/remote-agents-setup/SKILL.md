---
name: remote-agents-setup
description: Set up Cursor CLI remote runs and external MCP clients against the Thunderstone mailbox bridge.
---
# Remote agents setup

Use the existing bridge, Funnel, and token files. Do not rebuild them. Never print token values.

1. Status: `bash $THUNDERSTONE_ROOT/scripts/remote-agents.sh status` (bridge, funnel, dc, tailscaled, cursor-cloud).
2. Mint a client: `add-client <name>`. Hash goes to `~/.config/thunderstone-bridge/tokens.json`. Plaintext goes to `tokens/<name>.token` mode 0600. The bridge pane restarts.
3. Revoke: `revoke-client <name>` (drops hash and plaintext, restarts bridge).
4. CLI remote: `cli <brief.md>` runs `scripts/run-task.sh`. Prefer `agent -p --trust --force` when the starter is updated; today the starter is `agent -p` only.
5. Cloud: `agent --help` has `worker`, not a cloud-launch flag. Hosted Cloud Agents go through Cursor or Grok Bot.
6. Public URL: `https://grok-bot-vm-347906125.tail6c4b90.ts.net/mcp`.
7. ChatGPT Developer mode custom MCP: OAuth, none, or mixed — not a static bearer. Do not connect this bridge that way.
8. Claude custom connector: OAuth gap against bearer-only bridge.
9. Perplexity: API Key mode sends `Authorization: Bearer`. Use the perplexity token file.
