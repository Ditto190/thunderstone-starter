# Architecture

Config lives in Git. Runtime installs, auth, trust, and secrets stay on the machine. Grok Bot holds routing policy and does not store executable hook config.

| Layer | Owns |
|---|---|
| Git repository | Hook registrations, lifecycle dispatcher, Composio skill, tests, docs, `AGENTS.md`, update scripts, project `xai-docs` MCP URL |
| Cursor / Grok Build | Loads and executes repo config for the active checkout |
| Grok Bot | Task routing, delegation, roles, approval rules |
| VM desktop | LeanCTX binary, Grok/Cursor installs, user MCP registrations, logins, env secrets, trust, caches, logs |
| Cursor Cloud worker | Its own install, auth, trust, and state |
| Google Drive | Curated knowledge, releases, evidence, human-facing records |

## Lifecycle events

Cursor registrations (`.cursor/hooks.json`) all call `.cursor/hooks/lifecycle.sh` and are fail-open:

`sessionStart`, `sessionEnd`, `beforeSubmitPrompt`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `subagentStart`, `subagentStop`, `preCompact`, `stop`.

Grok-only registrations (`.grok/hooks/thunderstone.json`) are the events Cursor does not represent:

`PermissionDenied`, `StopFailure`, `Notification` (idle-notification backstop), `PostCompact`.

Grok reads `.cursor/hooks.json` as well. Those Grok-only names are not repeated there, so one event does not fire twice. Cancellation is `stop` in Cursor and `Stop` / `StopFailure` in Grok; current Grok docs do not define a separate cancel event.

`sessionStart` order is LeanCTX observe, then `.cursor/hooks/stage-router.sh`. Other events only observe. Disable a hook with `false` in `.cursor/hooks/lifecycle.config.json`. Missing LeanCTX, timeouts, and bad output do not block the agent.
