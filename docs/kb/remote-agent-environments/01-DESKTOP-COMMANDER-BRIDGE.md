# Desktop Commander bridge

## Chapter 1. Sources
https://github.com/mcp/app.desktopcommander/remote-desktop-commander
https://desktopcommander.app/mcp/
Hosted endpoint: https://mcp.desktopcommander.app/mcp
Documented transport: Streamable HTTP. Authentication: OAuth. Device agent requires Node 18+. The hosted service is beta; commands run with the paired user's OS permissions. Verify current provider instructions before installation.

## Chapter 2. Inspect
```bash
pwd
id
uname -s
node --version
npm --version
command -v agent || true
command -v tmux || true
git status --short
npm view @wonderwhy-er/desktop-commander version engines dist.integrity
```
Read the actual checkout's AGENTS.md. Do not dump environment variables.

## Chapter 3. Pair
Upstream discovery command:
```bash
npx @wonderwhy-er/desktop-commander@latest remote
```
Select an exact verified version for lasting setup. Human signs in and verifies the pairing code. Do not publish codes or tokens.
Keep the device agent running. A dedicated tmux session can survive terminal disconnection but not reboot. Use the observed service manager only after foreground validation; do not assume user systemd exists. Prevent duplicate agents.

## Chapter 4. Custom connector
```text
Name: Thunderstone VM Desktop Commander
URL: https://mcp.desktopcommander.app/mcp
Transport: Streamable HTTP
Authentication: OAuth
Target: verified paired development VM
```
Register in the client's remote-connector UI and complete OAuth. Compatibility is NOT VERIFIED until tool discovery and actual reads work.
Optional Cursor configuration, merge only:
```json
{"mcpServers":{"remote-desktop-commander":{"url":"https://mcp.desktopcommander.app/mcp"}}}
```

## Chapter 5. Acceptance and rollback
Discover actual tool schemas. Identify the correct device, ping it, read AGENTS.md and execute pwd/id. Use an approved disposable marker for write/read testing. Record config-written, authenticated and functional separately.
Stop only this bridge process and revoke only its pairing for rollback. Preserve project files.
Desktop Commander documented tools cover files, terminal and processes; do not infer full desktop mouse/keyboard control. Browser automation: https://github.com/microsoft/playwright-mcp. Cursor worker reference: https://cursor.com/docs/cloud-agent/self-hosted/my-machines. Check installed flags before registering workers or enabling computer use.
