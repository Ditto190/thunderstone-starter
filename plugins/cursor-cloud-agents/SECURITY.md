# Security gate (Git-Scout)

Checklist before any live use or promotion of `cursor-cloud-agents`.

- Token: `CURSOR_API_KEY` is an env name only. No value in `plugin.json`, `mcp.json`, skills, tests, or this file. Unexpanded `${...}` placeholders count as unset.
- Transport: the key is sent as `Authorization: Bearer` over https, or http only to loopback. `redirect: "error"` so a redirect cannot move the key.
- Redaction: tool results, error messages, and debug stderr pass through `redact` / `redactDeep`. The key, its base64 forms, and bearer/basic blobs are replaced. Raw error bodies are not copied into tool results.
- No PR by default: `autoCreatePR` defaults to false. A PR is opened only when the caller sets `autoCreatePR: true`.
- Branch: every launch sends `workOnCurrentBranch: false`. The agent pushes a new `cursor/` branch.
- Confirm gates: `launch_agent` and `cancel` do nothing unless `confirm` is boolean `true`.
- Launch cap: `CURSOR_MAX_LAUNCHES_PER_SESSION` (default 3, hard max 20). A definite 4xx refunds the slot; timeouts and 5xx do not.
- Allow-list: `CURSOR_CLOUD_AGENTS_ALLOWED_REPOS` is an optional comma-separated list of URL prefixes. Unset or blank allows every http(s) repo. A miss returns `repo_not_allowed` and sends no request.
- No delete: the server has no delete, archive, or unarchive tool and issues no `DELETE`.
- Live smoke: `scripts/smoke-live.mjs` exits before any socket unless `CURSOR_API_KEY` is set and `--confirm` is passed. `--launch` also needs `--repo`. Do not run it from CI.
- Artifacts: download URLs are presigned and short-lived. Do not paste them into chat.
