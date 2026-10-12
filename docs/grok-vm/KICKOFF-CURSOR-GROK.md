# Thunderstone Grok VM build kickoff (Cursor + Grok Bot)

Single handoff from Perplexity search `efadbc8f-d850-4119-b6f3-0eb45bf7bfe1` and Drive Notes (latest MCP connector + Grok VM skills exports). **Repo owns config; VM owns installs and secrets; Grok Bot owns routing policy.**

## Architecture placement

| Layer | Owns |
| --- | --- |
| **Git (`Ditto190/thunderstone-starter`)** | Hooks, MCP manifest, skills, tests, docs |
| **Grok Build / Cursor** | Load repo config for active checkout |
| **Grok Bot** | Task routing, quota-aware delegation to Cursor CLI |
| **VM desktop** | `bootstrap.sh`, `agent-setup.sh`, OAuth, `~/.grok/config.toml`, tmux |
| **Cursor Cloud** | Separate MCP enablement at cursor.com/agents (not implied by commits) |
| **Google Drive** | Curated notes, exports, evidence |

## Build order

1. Merge MCP/agent-connectors baseline + lifecycle + Composio skill (this branch).
2. CI: `npm test` green.
3. VM: `sh scripts/bootstrap.sh` → `bash scripts/agent-setup.sh --install` → `bash scripts/resume.sh`.
4. VM: `bash scripts/agent-setup.sh --sync` and `bash scripts/doctor.sh`.
5. Authenticate: `agent login` (Cursor), Grok MCP OAuth where prompted, optional `PERPLEXITY_API_KEY` in `.env.local`.
6. Canary: session hooks, `grok mcp doctor xai-docs`, one bounded `run-task.sh` brief.

---

## Cursor Cloud Agent — your steps

1. Check out branch `cursor/thunderstone-grok-handoff-5766` (or merged main).
2. Confirm files: `.cursor/hooks.json`, `.cursor/hooks/lifecycle.sh`, `config/mcp/servers.json`, `.agents/skills/composio/`.
3. Run `npm test`; fix any regressions.
4. Enable MCP in **cursor.com/agents** (personal): `xai-docs`, Context7, GitHub plugin (preferred over `github-remote`).
5. Do **not** require `XAI_API_KEY` for documentation-only tasks.
6. Open PR to `main` with validation evidence (CI + hook test output).
7. Optional: `node scripts/env-run.mjs bash scripts/run-task.sh docs/grok-vm/KICKOFF-CURSOR-GROK.md` for a bounded CLI worker (no auto-approve).

## Grok Bot / Grok Build on the VM — your steps

1. Pull the same branch into your durable VM workspace checkout (Thunderstone starter directory on the Grok Bot computer).
2. Run `bash scripts/agent-setup.sh --install` then `--sync` (writes gitignored `.grok/config.toml` and `.cursor/mcp.json`).
3. Register xAI docs if missing:
   ```bash
   grok mcp add --transport http xai-docs https://docs.x.ai/api/mcp
   grok mcp doctor xai-docs
   ```
4. Optional Composio (after reading `.agents/skills/composio/SKILL.md`): add remote `https://connect.composio.dev/mcp` in Grok Bot MCP UI; complete OAuth; enable tools per task.
5. Install LeanCTX on the VM when ready; lifecycle hooks already forward to `lean-ctx hook observe` when the binary exists (fail-open today).
6. Execute **VM canary** (below) before claiming production-ready.

## Shared acceptance checklist

| Check | Cursor | Grok VM |
| --- | --- | --- |
| `npm test` | required | required in checkout |
| Lifecycle events registered | `.cursor/hooks.json` | same file (Grok reads compatible hooks) |
| `xai-docs` in synced MCP config | after `--sync` + Cloud enable | `grok mcp doctor` |
| Composio skill present | `.agents/skills/composio` | same |
| No secrets in git | hygiene scripts | `env-run.mjs` only |
| Stage router on session start | via `lifecycle.sh` | same |

## VM canary (six steps)

1. `bash scripts/resume.sh` → attach tmux `thunderstone`.
2. `bash scripts/doctor.sh` — note OPTIONAL grok/agent until installed.
3. `bash scripts/agent-setup.sh --doctor`.
4. Trigger a new Cursor/Grok session; confirm hook scripts run without blocking (fail-open).
5. Call `xai-docs`: list doc pages + fetch `developers/docs-mcp`.
6. Record PASS/FAIL/NOT RUN in Drive export or PR comment — distinguish **configured** vs **connected**.

## Orchestration notes (Chiefs)

- **Quota-efficient path:** Grok Chief → `scripts/run-task.sh` + Cursor CLI worker (see Drive Notes / `grokbot_vm_agent_pack.md`).
- **Parallel work:** independent test files or docs may use parallel agents; one owner per repo branch.
- **pstack:** set `~/.cursor/rules/pstack-models.mdc` via `/setup-pstack` on the VM (swarm workers default to Grok fast family unless overridden).

## Open decisions (defaults assumed)

- Composio mode: **For You** first; Platform only for app-user OAuth flows.
- Hooks: **fail-open** (never block the agent).
- Paid xAI inference / batch / LiteLLM: **disabled** in bootstrap until explicitly approved.
