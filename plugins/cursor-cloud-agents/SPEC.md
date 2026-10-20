# cursor-cloud-agents v1 contract

Verified against https://cursor.com/docs/cloud-agent/api/endpoints on 2026-10-20 (public beta).
Auth on the docs page is Basic (`-u KEY:`) or Bearer. This server sends Bearer only.
Fields this plugin does not send (images, env, envVars, mcpServers, customSubagents, model.params, agentId) are omitted here.

## Status enums

Agent `status`: `ACTIVE` | `IDLE` | `ARCHIVED`.

Run `status`: `CREATING` | `RUNNING` | `FINISHED` | `ERROR` | `CANCELLED` | `EXPIRED`.
`durationMs` is set once the run is one of `FINISHED`, `ERROR`, `CANCELLED`, `EXPIRED`.

## REST shapes this server uses

### POST /v1/agents

Request (subset):

```json
{
  "prompt": { "text": "string" },
  "model": { "id": "string" },
  "name": "string",
  "repos": [{ "url": "https://...", "startingRef": "string", "prUrl": "https://..." }],
  "workOnCurrentBranch": false,
  "autoCreatePR": false,
  "mode": "agent"
}
```

`repos[].url` is any connected provider, including GitHub and GitLab (cloud or self-hosted). `url` stays required when `prUrl` is set. `mode` is `agent` (default) or `plan`.

Response `201` (example status `ACTIVE` / `CREATING`):

```json
{ "agent": { "id": "bc-...", "status": "ACTIVE", "url": "https://cursor.com/agents/bc-...", "latestRunId": "run-..." }, "run": { "id": "run-...", "agentId": "bc-...", "status": "CREATING" } }
```

### GET /v1/agents

Query: `limit` (default 20, max 100), `cursor`, `prUrl`, `includeArchived` (default true).
Response: `{ "items": [ { "id", "name", "status", "env", "url", "createdAt", "updatedAt", "latestRunId" } ], "nextCursor": "..." }`.
`nextCursor` is omitted (not null) when there are no further pages. List items omit full `repos`.

### GET /v1/agents/{id}

Response includes `repos`, `workOnCurrentBranch`, `autoCreatePR`, `latestRunId`, and agent `status`.

### POST /v1/agents/{id}/runs

Request: `{ "prompt": { "text": "string" }, "mode": "agent" }`.
Response: `{ "run": { "id", "agentId", "status": "CREATING", "createdAt", "updatedAt" } }`.
While another run is `CREATING` or `RUNNING`: `409` with code `agent_busy`.

### GET /v1/agents/{id}/runs/{runId}

Base fields always: `id`, `agentId`, `status`, `createdAt`, `updatedAt`.
When present: `durationMs`, `result`, `git.branches[]` of `{ repoUrl, branch?, prUrl? }`.
`git.repoUrl` is returned without a scheme (`github.com/org/repo`). That differs from request `repos[].url`.

### POST /v1/agents/{id}/runs/{runId}/cancel

Response: `{ "id": "run-..." }`. Terminal or never-active run: `409` code `run_not_cancellable`.

### GET /v1/agents/{id}/artifacts

Response: `{ "items": [ { "path": "artifacts/screenshot.png", "sizeBytes": 0, "updatedAt": "..." } ] }`.
Paths are relative and must stay under `artifacts/`.

### GET /v1/agents/{id}/artifacts/download?path=

Response: `{ "url": "https://...", "expiresAt": "..." }` (about 15 minutes).

## Error bodies

Documented shapes this client accepts:

- `{ "code": "agent_busy", "message": "..." }` (stream errors and several named REST codes).
- `{ "error": "Worker in use: ...", "message": "..." }` or `{ "error": "..." }` (common REST).
- Nested `{ "error": { "code": "...", "message": "..." } }` — **unverified** as a documented body; accepted so a nested code is not dropped.

Named codes seen on the endpoints page for calls we make: `validation_error` (400), `agent_busy` (409), `run_not_cancellable` (409), `run_not_found` (404), `agent_id_conflict` (409, only if a client `agentId` is sent — we never send one).

HTTP 401, 403, and 429 are **not** given a single body schema on the agents endpoints page. The client maps status to `unauthorized`, `forbidden`, `not_found`, `rate_limited` when the body has no `code`. `Retry-After` (integer seconds) is copied to `retryAfterSeconds` when present. A 429 body example on this page is only for private-worker claim tokens, not for `/v1/agents`.

## Tool schemas

Shared error object: `{ code, message, status?, retryable?, retryAfterSeconds?, hint? }`.
Tool failures are MCP tool results with `isError: true` and that object under `error`. They are not JSON-RPC protocol errors.

| Tool | Input (additionalProperties false) | Output |
| --- | --- | --- |
| `launch_agent` | required `prompt`, `repoUrl`, `confirm`. Optional `startingRef`, `prUrl`, `model`, `name`, `mode` (`agent`\|`plan`), `autoCreatePR` (default false). | `{ agentId, runId, agentStatus, runStatus, url, autoCreatePR, nextPollSeconds, launchesUsed, launchesRemaining }` |
| `get_status` | required `agentId`. Optional `runId`. | `{ agent, run, terminal, nextPollSeconds, runError? }` |
| `followup` | required `agentId`, `prompt`. Optional `mode`. | `{ agentId, runId, runStatus, nextPollSeconds }` |
| `list_agents` | optional `limit` 1–100, `cursor`, `prUrl`, `includeArchived`. | `{ items, nextCursor? }` |
| `cancel` | required `agentId`, `confirm`. Optional `runId`. | `{ agentId, runId, cancelled: true }` |
| `get_artifacts` | required `agentId`. Optional `path`. | list: `{ agentId, items }`; download: `{ agentId, path, url, expiresAt, note }` |

Local error codes (no HTTP call): `invalid_input`, `confirmation_required`, `launch_cap_reached`, `repo_not_allowed`, `missing_api_key`, `invalid_base_url`, `no_run`.
Transport: `timeout`, `network_error`, `invalid_response`. HTTP fallbacks: `bad_request`, `unauthorized`, `forbidden`, `not_found`, `conflict`, `gone`, `rate_limited`, `server_error`, `http_error`.
`followup` rewrites a 409 `conflict` (no code) to `agent_busy` (retryable). `cancel` rewrites any 409 to `run_not_cancellable`.
