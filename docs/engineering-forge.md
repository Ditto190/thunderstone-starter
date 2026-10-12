# Engineering Forge kickoff

Portable configuration lives in this repository. The VM owns installed
binaries, authentication, secrets, and trust. Grok Bot owns routing policy.
Cursor Cloud does not inherit the Grok VM.

## What this checkout contains

| Piece | Path | Status |
| --- | --- | --- |
| Lifecycle dispatcher | `.cursor/hooks/lifecycle.sh` | Implemented, fail-open |
| Cursor registrations | `.cursor/hooks.json` | Implemented |
| Grok-only registrations | `.grok/hooks/lifecycle.json` | Implemented |
| Stage advisory | `.cursor/hooks/stage-router.sh` | Unchanged; `sessionStart` delegates to it |
| Composio skill | `.agents/skills/composio/` | Vendored at a pinned commit |
| Connector catalogue | `config/connectors/cursor-mcp.example.json` | Example only |

`.cursor/mcp.json` stays gitignored. Copy the example locally when a checkout
needs the project file. Do not commit API keys.

## Hook policy

Every registered hook is installed and tested. None are omitted because a
workflow has not selected them yet. None of these hooks block the agent.
A non-zero exit, timeout, missing `lean-ctx`, or malformed payload fails open
and prints `{}` except `sessionStart`, which prints the stage-router advisory.

Cursor events: `sessionStart`, `sessionEnd`, `beforeSubmitPrompt`,
`preToolUse`, `postToolUse`, `postToolUseFailure`, `subagentStart`,
`subagentStop`, `preCompact`, `stop`.

Grok-only events, in `.grok/hooks/lifecycle.json` because Cursor does not
define them: `PermissionDenied`, `StopFailure`, `StopCancelled`, `PostCompact`,
and `Notification` matched to `idle_prompt`. Shared events stay in
`.cursor/hooks.json`. Grok loads that file and maps the camelCase names, so
they are not registered twice.

`lean-ctx hook observe` runs only when both `lean-ctx` and `timeout` exist.
The payload is forwarded unchanged. Output is discarded.

## Connectors

| Server | Where it belongs | Secret |
| --- | --- | --- |
| xai-docs `https://docs.x.ai/api/mcp` | Example catalogue and host MCP settings | None |
| Context7 | Example catalogue using `CONTEXT7_API_KEY` | Env only |
| GitHub | Cursor Marketplace plugin already used by this project | Do not add a second `mcpServers.github` entry |
| GitLab | Host plugin when the instance exposes `/api/v4/mcp` | Host auth |

Copy `config/connectors/cursor-mcp.example.json` to `.cursor/mcp.json` only on
a machine that should load those project servers. Cloud and desktop hosts that
already enable the same servers do not need a second registration.

Paid xAI inference, LiteLLM routing, and batch submission stay out of
`bootstrap.sh` and `resume.sh`.

## Composio

The skill is a router. It does not connect an account. For You and Platform
use different credentials and must not be mixed. Mode is not chosen in this
change. Update only with an explicit commit:

```sh
bash scripts/update-composio-skill.sh <40-hex-sha>
```

Provenance is `.agents/skills/composio/PROVENANCE.json`. CI checks hashes and
does not call the network.

## VM steps after merge

1. Trust the checkout in Grok (`/hooks-trust` or `grok --trust`) so project hooks load.
2. Install `lean-ctx` only from a reviewed release. `doctor.sh` reports it as optional.
3. Reload the host so hook registrations are picked up.
4. Canary, in order: session start, a successful tool, a failed tool, compaction, stop, session end.
5. Enable Composio For You or Platform only after choosing the mode. Keep secrets out of git.

## Acceptance

- `npm test` passes, including lifecycle and provenance tests.
- Hook scripts are executable and are not gitignored.
- No hook returns a deny decision.
- xAI docs access does not require `XAI_API_KEY`.
