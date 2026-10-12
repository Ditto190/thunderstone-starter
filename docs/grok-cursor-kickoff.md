# Thunderstone kickoff: Cursor and Grok

One checkout owns portable configuration. The VM owns installed binaries, login, secrets, and trust. Grok Bot owns routing and approval. This file is the build contract for both.

## Placement

| Layer | Owns |
| --- | --- |
| Git repository | Hook registrations, lifecycle dispatcher, pinned Composio skill, tests, this guide |
| Cursor and Grok Build | Load the checkout after the folder is trusted |
| Grok Bot | Task routing, worker choice, approval before external writes |
| VM | `lean-ctx`, `grok`, `agent`, authenticated MCP sessions, env files |
| Cursor Cloud | Its own install and auth. It does not inherit the Grok Bot VM |
| Google Drive | Curated notes. Promoted code stays on GitHub |

## What is already in the repo

- `.cursor/hooks/lifecycle.sh` fail-open dispatcher. `sessionStart` still runs `.cursor/hooks/stage-router.sh`.
- `.cursor/hooks.json` registers session start/end, prompt submit, tool use and failure, subagent start/stop, pre-compaction, and stop. Every entry has `failClosed: false`.
- `.grok/hooks/thunderstone.json` registers Grok-only events: permission denial, stop failure, stop cancellation, post-compaction, and idle notification.
- When `lean-ctx` is on `PATH` or at `$HOME/.local/bin/lean-ctx`, each event is forwarded to `lean-ctx hook observe`. A missing binary, timeout, or error does not block the agent.
- `.agents/skills/composio/` is the Composio skill at commit `f9ce49953598e13371c406ac346846696a4d8385`, with `PROVENANCE.json` hashes.
- `config/mcp.example.json` is the connector template. `.cursor/mcp.json` stays gitignored.

Hooks that no workflow selects yet are still registered and covered by `tests/lifecycle-test.sh`.

## Cursor steps

1. Stay on a feature branch. Do not push to `main`.
2. Keep hook scripts, tests, and `.agents/skills/composio/` tracked. Do not gitignore them.
3. Copy `config/mcp.example.json` to the gitignored `.cursor/mcp.json` only on a machine that should load those servers.
4. Authenticate Context7 with `CONTEXT7_API_KEY` in the environment. Do not commit the value.
5. Do not add a GitHub MCP entry. Use the GitHub plugin already connected to Cursor.
6. Leave GitLab unauthenticated until that instance confirms `https://gitlab.com/api/v4/mcp`.
7. Run `npm test`. It includes stage-router fixtures, lifecycle registration, fail-open behavior, and Composio hash checks.

xAI documentation uses `https://docs.x.ai/api/mcp` with no API key. Do not add `XAI_API_KEY` for docs access. Do not enable LiteLLM xAI routing or batch submission in bootstrap.

## Grok steps

1. Install or confirm `grok` and, if context selection is wanted, `lean-ctx`. `bash scripts/doctor.sh` reports both as optional when missing and requires the lifecycle files.
2. Trust this checkout (`/hooks-trust` or `grok` `--trust`) or project hooks stay skipped.
3. Grok reads `.cursor/hooks.json` and `.grok/hooks/thunderstone.json`. Do not duplicate the Cursor events in the Grok file.
4. Register docs MCP only if it is absent:

```bash
grok mcp add --transport http xai-docs https://docs.x.ai/api/mcp
grok mcp doctor xai-docs
```

5. Turn on Composio only after choosing For You or Platform. The vendored skill routes those products and they must not share credentials. Installing the skill does not connect an account.
6. Refresh the pin with an explicit SHA:

```bash
bash scripts/update-composio-skill.sh <40-hex-sha>
```

## Connector catalogue

| Server | URL | Auth in this repo |
| --- | --- | --- |
| xai-docs | `https://docs.x.ai/api/mcp` | None |
| context7 | `https://mcp.context7.com/mcp` | `CONTEXT7_API_KEY` header from the environment |
| gitlab | `https://gitlab.com/api/v4/mcp` | Not configured here |

Copying the example does not prove a client connected. Report configured, connected, and verified separately.

## Canary

1. Start a trusted Grok or Cursor session in this checkout.
2. Confirm `sessionStart` returns stage-router JSON or `{}`.
3. Run a successful tool and a failing tool. The dispatcher must exit 0.
4. Confirm compaction and stop still exit 0.
5. End the session. `sessionEnd` must exit 0.
6. `bash scripts/doctor.sh` shows lifecycle hooks OK. `lean-ctx` may stay optional.

## Open choices

- Composio mode is not selected. Both reference docs are vendored. Connect For You, Platform, or both only after an explicit choice.
- No hook blocks the agent. `failClosed` is false, and the dispatcher always exits 0.
- A hosted Engineering Forge MCP is not part of this change.

## Acceptance

- `npm test` passes.
- No secret values and no machine-specific absolute paths are committed.
- `XAI_API_KEY` is not required to read xAI docs.
- Bootstrap does not perform OAuth, paid inference, or batch submission.
