# Agent platform E2E triage (2026-10-11)

Multi-agent review of `thunderstone-starter` against Drive KB, thermo-nuclear quality bar,
architect/domain modeling, and the **build-agents** (eve) path. This repo is a **VM control
plane**, not a product agent runtime (see planned ADR on `docs/catalogue-mcp-adr`).

## Current state

| Layer | Status |
|-------|--------|
| Bootstrap / resume / tmux | Shipped (`scripts/bootstrap.sh`, `resume.sh`) |
| Cursor Cloud env | Shipped; **hardcoded `/agent/repos/thunderstone-starter` paths** (portability smell) |
| Task execution | Thin `run-task.sh` → `agent -p` prose; no brief schema or run ledger |
| Validation / hygiene | Strong for infra (`npm test`, gitleaks, stage-router tests) |
| Drive export | Manual curate → `export-drive.sh` |
| `config/clan.yaml` | **Policy YAML with no consumer** in `main` |
| MCP / Perplexity / skills | **`feat/agent-connectors`** (~700 LOC); not on `main` |
| Browser stack | **`feat/browser-stack`**; PLAN defers live VM smoke |
| eve durable agents | **Not started** (separate repo per build-agents skill) |
| Instruction compiler + Perplexity MCP server | **Drive KB only** (`perplexity-agent-docs-rag.zip`, deep-dive MDs) |

### Documented E2E today

```text
resume.sh → workspace/briefs/<TASK>.md → env-run + run-task.sh → workspace/reports/
→ (human) workspace/exports/ → export-drive.sh
```

Gaps: no brief/report templates in git, no automated validate/report/export/handoff chain, no
connector authority in clan config, CI does not exercise agent workflow.

## Google Drive KB (authoritative context)

| Asset | Role |
|-------|------|
| `agent-instruction-deep-dive.md` | IR compiler, GitHub/Drive adapters, Perplexity remote MCP design |
| `Extract all agent files…md` | TS implementation spec (scan/decompile/compile CLI) |
| `perplexity-agent-docs-rag.zip` | RAG / connector artefacts |
| `Thunderstone_Engine_Forge_starter.md` | xAI `xai-docs` MCP (`https://docs.x.ai/api/mcp`) |
| `Thunderstone-VM-Redis-Agent-Guides.zip` | VM + Redis KB ingestion guides |
| `drive-thunderstone-navigator-skill-v1.zip` | Drive navigation skill |
| `agent-profiles-20261010.json` | Grok marketplace profile export (Git-Scout, auditors, etc.) |
| `Grokbot_Agents_Config.md` | VM Operations Chief orchestration pattern |

**Perplexity (two products):**

1. **Search MCP** (API key): stdio `@perplexity-ai/mcp-server` on `feat/agent-connectors`, or
   Streamable HTTP `https://api.perplexity.ai/mcp` + Bearer (documented manual path).
2. **Computer / Comet**: OAuth; configured in Perplexity app, not this repo.

## Parallel review summary

### Thermo-nuclear (blockers on `main`)

- Stale `manifest.sha256` (fails locally; not in CI).
- `.cursor/environment.json` absolute paths; hygiene does not flag `/agent/`.
- `clan.yaml` unused; `run-task.sh` prompt-only enforcement of no recursion.
- `stage-router.sh`: portability (bash 3.2), sequential `gh` budget, duplicate hygiene regexes.
- Merge **`feat/agent-connectors` only after rebase** onto stage-router CI (validate.sh regression).

### Architect + model-the-domain (target shape)

- **Compiled IR** from `clan.yaml` + `config/mcp/servers.json` + `config/skills/manifest.json`
  → `.state/clan.ir.json` → emit `.cursor/mcp.json`, `.grok/config.toml`, marked sections of
  `AGENTS.md`.
- **Task frontmatter** selects executor, risk, connectors, skills, acceptance commands (not
  scattered `if` in scripts).
- **Run kernel**: `workspace/runs/<runId>/ledger.jsonl` + `report.md` + `handoff.json`.
- **eve** = P2 executor in another repo; pins IR bundle; subagents off per clan law.

Full module map and phases: see agent output in PR / follow-up `docs/agent-platform-blueprint.md`.

## Triage backlog (build-agents / E2E)

### P0 — Unblock merge and honest contracts

| Item | Owner surface | Notes |
|------|---------------|-------|
| Rebase + merge `feat/agent-connectors` | scripts, config | Restore stage-router tests in `validate.sh` |
| Fix or remove `manifest.sha256` | hygiene | Generate in release or delete |
| Portable Cloud `environment.json` | `.cursor/` | Repo-root discovery; document `/agent` allow-list |
| Brief + report templates | `docs/templates/` | YAML frontmatter per architect schema |
| `task lint` before any `agent` call | `scripts/task.mjs` | Enforce clan + connector invariants |
| Unify doctor/check helpers | `scripts/lib/` | Before connector branch adds 4th doctor |

### P1 — Perplexity + MCP “connect”

| Item | Notes |
|------|-------|
| Set `PERPLEXITY_API_KEY` via `env-run` / Cursor secrets | Required for search MCP |
| Merge `servers.json` pipeline as **single MCP source** | Deprecate duplicating `mcp.example.json` manually |
| Add **hosted** Perplexity transport | `url` + Bearer header in `mcp-sync` for Cloud/headless |
| Register **Perplexity custom connector** (org admin) | Streamable HTTP to deployed compiler MCP when ready |
| Wire **xai-docs** | Already available as MCP in Cursor; add to `servers.json` |
| Google Drive MCP | Use for KB search (`search_files`); optional cache under `.state/drive-kb/` |

### P2 — eve + compiler + fleet

| Item | Notes |
|------|-------|
| Import or submodule Drive **instruction compiler** project | Implements deep-dive MCP tools |
| `npx eve@latest init thunderstone-eve` | Durable sessions, channels, Connect |
| Redis KB ingest | Branch `docs/vm-redis-kb-20261011` when query consumer exists |
| Browser stack live smoke | `feat/browser-stack` deferred items |
| Handoff generator | `feat/handoff-contract-generator` (empty diff vs main today) |

## Remote branches map

| Branch | Intent |
|--------|--------|
| `feat/agent-connectors` | MCP sync, skills, agent-setup, Perplexity stdio |
| `feat/browser-stack` | CloakBrowser + agent-browser MCP |
| `docs/portable-agent-workspace-plan` | Workspace portability |
| `docs/vm-redis-kb-20261011` | Redis ingestion contract |
| `docs/catalogue-mcp-adr` | Control-plane ADR, catalogue MCP |
| `ci/run-task-force-lean-off` | run-task / lean-ctx policy |

## Approval bar (thermo-nuclear)

Do **not** treat `main` as E2E-ready until: clan config is enforced, one run produces
ledger + report without prompt-only policy, Perplexity transport matches your chosen default
(stdio vs Streamable HTTP), and connector merge does not regress CI.

## Next actions (recommended order)

1. Merge P0 connector branch after rebase + `npm test`.
2. Add `PERPLEXITY_API_KEY` and run `agent-setup.sh --doctor` on a VM.
3. Land `task.mjs` + templates (P0) before eve work.
4. Pull compiler zip from Drive into a **separate** GitHub repo; deploy read-only MCP; register in Perplexity.
5. Scaffold eve agent repo with executor port matching ledger/report schemas.
