# Computer use, browsers and Windows

## Grok Bot VM (profile `vm`)

The VM belongs to the Grok Bots and they have full control of it. Two tools are installed there and enabled by default:

- `computer-use` (`computer-use-mcp`): screenshots, mouse and keyboard through nut.js. nut.js needs X11, which Xfce provides. The server only works inside the desktop session, so `--doctor` warns when `DISPLAY` is unset.
- `cua-driver` (trycua): `scripts/agent-setup.sh --install` downloads the official installer to `.state/` and runs it on x86_64 Linux. It runs as `cua-driver mcp`. Opt out with `SKIP_CUA_INSTALL=1`. If the installer fails, run it by hand from the Cua Driver docs and rerun `--sync`.

Browser tiers (see `docs/browser-stack/ROUTING.md`): Firecrawl, Scrapling, then `agent-browser` on the CloakBrowser CDP sidecar. `--start` launches the sidecar when Docker is reachable; without Docker it prints a warning and the other tiers keep working.

## Cursor and other machines (profile `dev`)

Computer-use servers stay off so an agent cannot take over a personal desktop. Turn one on deliberately with `MCP_ENABLE=computer-use`. `chrome-devtools` is also off by default and attaches to the CloakBrowser CDP port.

## Windows-MCP

Windows-MCP (`CursorTouch/Windows-MCP`) is Windows only and needs Python 3.13 and `uv`, so it does not run in the Linux VM and is not installed there. `mcp-sync` also exits on Windows rather than writing a Linux-style config.

For Cursor on Windows 11, merge this into `%USERPROFILE%\.cursor\mcp.json` (global) and restart Cursor. The first start can time out while dependencies install; restart once more.

```json
{
  "mcpServers": {
    "windows-mcp": {
      "command": "uvx",
      "args": ["windows-mcp@0.8.8", "serve"]
    },
    "perplexity": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@perplexity-ai/mcp-server@1.3.0"],
      "env": { "PERPLEXITY_API_KEY": "${env:PERPLEXITY_API_KEY}" }
    }
  }
}
```

Set `PERPLEXITY_API_KEY` as a user environment variable first. Perplexity Computer cannot reach a localhost Windows-MCP, so do not tunnel it for that.
