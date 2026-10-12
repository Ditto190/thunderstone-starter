# Hooks

`.cursor/hooks/lifecycle.sh` is the single dispatcher. The event name is the first argument (or `GROK_HOOK_EVENT`, or `hookEventName` in the JSON body). The raw stdin payload is forwarded unchanged to `lean-ctx hook observe <event>` when the `lean-ctx` binary is on `PATH`.

## Event matrix

| Client | Event | Dispatcher argument | Also runs |
|---|---|---|---|
| Cursor | `sessionStart` | `sessionStart` | stage router, after observe |
| Cursor | `sessionEnd` | `sessionEnd` | observe only |
| Cursor | `beforeSubmitPrompt` | `beforeSubmitPrompt` | observe only |
| Cursor | `preToolUse` | `preToolUse` | observe only |
| Cursor | `postToolUse` | `postToolUse` | observe only |
| Cursor | `postToolUseFailure` | `postToolUseFailure` | observe only |
| Cursor | `subagentStart` | `subagentStart` | observe only |
| Cursor | `subagentStop` | `subagentStop` | observe only |
| Cursor | `preCompact` | `preCompact` | observe only |
| Cursor | `stop` | `stop` | observe only |
| Grok | `PermissionDenied` | `PermissionDenied` | observe only |
| Grok | `StopFailure` | `StopFailure` | observe only |
| Grok | `Notification` | `Notification` | observe only |
| Grok | `PostCompact` | `PostCompact` | observe only |

`sessionStart` hook timeout is 8 seconds so a 1 second observe budget can finish before the stage router’s own ~4 second budget. Every registration is fail-open (`failClosed: false` on the Cursor side).

## Fail-open

These do not block the agent. The dispatcher logs to stderr and still exits 0:

- `lean-ctx` missing
- observe timeout, non-zero exit, or empty output
- malformed stdin
- stage-router failure or non-JSON stdout on `sessionStart`

No hook is fail-closed. A disabled hook is still present in Git; it is skipped when its flag is `false`.

## Disable a hook

Edit `.cursor/hooks/lifecycle.config.json` and set that hook’s key to `false`. Keys are camelCase (`sessionStart`, `permissionDenied`, `postCompact`, …). `true` or a missing key leaves the hook active. Grok PascalCase names map onto those keys inside the dispatcher.

## Precedence

Grok loads project hooks from `.grok/hooks/*.json` and also loads `.cursor/hooks.json`. Thunderstone puts shared events only in the Cursor file and Grok-only events only in `.grok/hooks/thunderstone.json`. Do not copy a Cursor event into the Grok file or it can run twice.

## LeanCTX and xai-docs

`scripts/install-lean-ctx.sh` installs a binary from `LEAN_CTX_RELEASE_URL` (https only, optional `LEAN_CTX_SHA256`) into the user local bin directory. With the URL unset it prints a manual/optional line and exits 0. It does not guess a package name. User-scope MCP for LeanCTX belongs in the Grok user config, not in Git, because the command path is per machine. `bash scripts/doctor.sh` reports `lean-ctx`, `lean-ctx-mcp`, and `grok-trust` as optional until the VM has them.

`.grok/config.toml` registers one project MCP server, `xai-docs`, at `https://docs.x.ai/api/mcp` (Streamable HTTP, stateless). That single server covers the docs, inference, management, and collections guides.

## Composio

The vendored guidance is `.agents/skills/composio/` from `ComposioHQ/composio`, pinned by `PROVENANCE.json`. Refresh only with an explicit commit:

```sh
bash scripts/update-composio-skill.sh <40-hex-sha>
```

The skill does not connect accounts. Use For You or Platform, not both credential types in one setup. Activation (MCP, CLI, or SDK auth) happens outside Git after this change is merged.
