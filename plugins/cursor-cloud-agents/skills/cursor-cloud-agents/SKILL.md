---
name: cursor-cloud-agents
description: Launch, monitor, follow up, cancel and collect artifacts from Cursor Cloud Agents through the cursor-cloud-agents MCP tools. Use when work should run on a Cursor cloud VM against a GitHub or GitLab repository instead of locally.
---
# Cursor Cloud Agents

Tools (MCP server `cursor-cloud-agents`): `launch_agent`, `get_status`, `followup`, `list_agents`, `cancel`, `get_artifacts`.

## Rules
1. `launch_agent` and `cancel` need `confirm: true`. Set it only after the requester approved that exact action. Launches spend Cursor quota and are capped per session (default 3).
2. `launch_agent` returns `{agentId, runId}` at once. Do not wait inside the call; poll `get_status`.
3. Poll no faster than `nextPollSeconds`. When it is `null` the run is finished; read `run.result` and `run.git`.
4. `followup` on a busy agent returns `agent_busy` (retryable). Poll until the run ends, or `cancel` it, then retry.
5. No PR is opened unless `autoCreatePR: true`. The agent pushes a new `cursor/...` branch, never the starting branch.
6. There is no delete or archive tool. Never ask for one.
7. `get_artifacts` download links are temporary and sensitive; do not paste them into chats.
8. Never print, log or ask for `CURSOR_API_KEY`. If a tool says `missing_api_key`, tell the requester it must be supplied through a secret request.
9. If `launch_agent` returns `repo_not_allowed`, the URL is outside `CURSOR_CLOUD_AGENTS_ALLOWED_REPOS`. Do not retry with a different host to get around the list.
