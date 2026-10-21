# cursor-cloud-agents (M1, local stdio)

A zero-dependency Node (>= 22) stdio MCP server that wraps the Cursor Cloud Agents v1 REST API
(public beta, docs: https://cursor.com/docs/cloud-agent/api/endpoints). It is packaged as an
Agent Plugin: root `plugin.json`, `mcp.json`, and one thin skill.

Status: built and tested against a local fake HTTP server only. No live call to Cursor has been made.
Hosting (Streamable HTTP, Perplexity/xAI connectors) is out of scope for M1.

## Tools

| Tool | REST call | Notes |
| --- | --- | --- |
| `launch_agent` | `POST /v1/agents` | Needs `confirm: true`. Returns `{agentId, runId}` at once. `autoCreatePR` defaults to false; `workOnCurrentBranch` is always false (agent pushes a new `cursor/` branch). Capped per session. |
| `get_status` | `GET /v1/agents/{id}` then `GET /v1/agents/{id}/runs/{runId}` | Adds `terminal` and `nextPollSeconds` (null when finished). |
| `followup` | `POST /v1/agents/{id}/runs` | `409 agent_busy` becomes a structured, retryable error. |
| `list_agents` | `GET /v1/agents` | `limit`, `cursor`, `prUrl`, `includeArchived`. No `nextCursor` means no more pages. |
| `cancel` | `POST /v1/agents/{id}/runs/{runId}/cancel` | Needs `confirm: true`. Defaults to the latest run. `409` becomes `run_not_cancellable`. |
| `get_artifacts` | `GET /v1/agents/{id}/artifacts` (and `/artifacts/download?path=` when `path` is given) | The download link is a temporary presigned URL. |

There is deliberately no delete, archive or environment/secrets tool. The server never polls or
schedules anything on its own: the caller polls `get_status` at the `nextPollSeconds` pace.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `CURSOR_API_KEY` | none (required for any call) | Cursor API key. Sent as `Authorization: Bearer ...`. Never logged, never written to a file; redacted from every error. |
| `CURSOR_API_BASE_URL` | `https://api.cursor.com` | Override for tests. Must be https, except loopback hosts. |
| `CURSOR_MAX_LAUNCHES_PER_SESSION` | `3` | Launch cap per server process (0 to 20). Invalid values fall back to 3. |
| `CURSOR_REQUEST_TIMEOUT_MS` | `30000` | Per-request timeout (100 to 120000). |
| `CURSOR_MCP_DEBUG` | unset | `1` logs protocol notices to stderr (redacted). stdout stays protocol-only. |
| `CURSOR_CLOUD_AGENTS_ALLOWED_REPOS` | unset (allow all) | Comma-separated URL prefixes. `launch_agent` rejects anything else with `repo_not_allowed` and sends no request. |

`mcp.json` passes the key through as the placeholder `${CURSOR_API_KEY}`; no value is stored in the plugin.
If your client does not expand `${CURSOR_API_KEY}`, use `${env:CURSOR_API_KEY}` in a `.cursor/mcp.json` entry
(Cursor's documented interpolation) or export the variable before starting the client. An unexpanded
placeholder is treated as "key not set" and the tools return `missing_api_key`.

## Protocol

Newline-delimited JSON-RPC over stdio. Dual-era: the legacy `initialize` handshake
(2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05; the requested version is echoed if supported, otherwise
2025-11-25) and the stateless 2026-07-28 revision (`server/discover`, per-request `_meta`,
`resultType`, error `-32022` for unsupported versions). Methods: `initialize`, `server/discover`,
`ping`, `tools/list`, `tools/call`; notifications are accepted and ignored. Closing stdin ends the
process after in-flight calls finish.

## Tests (no network beyond loopback)

```bash
cd plugins/cursor-cloud-agents
node --test "test/*.test.mjs"
```

They run each tool against a fake `node:http` server (confirm guards, launch cap, 409 mapping, redaction,
timeouts, pagination) and spawn the real server to exercise the stdio protocol.

## DT-only step before first live use

Supply `CURSOR_API_KEY` through a secret request (never in chat or files). Then run one live smoke:
`list_agents` first (read-only), and only then a single confirmed `launch_agent` against a throwaway repo.
The live smoke has not been run.

## Install

This folder is an [Agent Plugin](https://cursor.com/docs/plugins): root `plugin.json` (not `.cursor-plugin/plugin.json`), root `mcp.json`, skill at `skills/cursor-cloud-agents/SKILL.md`. Cursor loads that layout. Use `${CURSOR_PLUGIN_ROOT}` in `mcp.json`; Cursor does not expand the Agent Plugins `${PLUGIN_ROOT}` variable.

### Cursor

1. Copy this directory to `~/.cursor/plugins/local/cursor-cloud-agents` (a symlink is loaded only when its target stays inside that local folder). Reload the window. Admins on Teams/Enterprise may need to allow local plugin imports.
2. Or register the server in the project file `.cursor/mcp.json` (placeholders only):

```json
{
  "mcpServers": {
    "cursor-cloud-agents": {
      "command": "node",
      "args": ["plugins/cursor-cloud-agents/server/index.mjs"],
      "env": { "CURSOR_API_KEY": "${env:CURSOR_API_KEY}" }
    }
  }
}
```

Set `CURSOR_API_KEY` in the environment Cursor interpolates. Do not paste the key into the file.

### Grok Bot or any stdio MCP client

Start the process with the key in the environment. Paths below are relative to the repo root.

```json
{
  "command": "node",
  "args": ["plugins/cursor-cloud-agents/server/index.mjs"],
  "env": { "CURSOR_API_KEY": "<set in the client env, never in this file>" }
}
```

The same binary speaks newline-delimited JSON-RPC on stdin/stdout (`initialize`, `tools/list`, `tools/call`).

## Local install for testing

See Install above. Contract: `SPEC.md`. Gate: `SECURITY.md`.
Live smoke (do not run unless a human passed `--confirm` and a key is already in the environment):

```bash
node plugins/cursor-cloud-agents/scripts/smoke-live.mjs --confirm
node plugins/cursor-cloud-agents/scripts/smoke-live.mjs --confirm --launch --repo https://github.com/org/throwaway
```
