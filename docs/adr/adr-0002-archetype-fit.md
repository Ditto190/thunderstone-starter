---
title: "ADR-0002: Archetype fit evaluation"
status: "Accepted"
date: "2026-10-11"
authors: "DT"
tags: ["architecture", "evaluation"]
supersedes: ""
superseded_by: ""
---

## Status

**Accepted** as the evaluation record. The decision it executes is `docs/adr/adr-0001-control-plane.md`, which stays Proposed until that branch merges.

Evaluated `thunderstone-starter` `main` at `44296197` against the control-plane archetype. Catalogues read live: `Ditto190/modme-ui-01` `.github/agents` (61 files) and `Ditto190/mcapp-ai-starter` `consolidated_sources/awesome-copilot` (the upstream dump). Official Grok surfaces from the grok-agent-ops pack (docs index compiled 2026-09-17). The awesome-copilot MCP those agents call was not connected in the session that wrote this. The MCP itself was then identified. See the last section.

## Fit

Repo Architect's three layers, from `mcapp-ai-starter` `consolidated_sources/awesome-copilot/agents/repo-architect.agent.md`, scored against the starter.

| Layer | Ideal | Thunderstone on main |
|---|---|---|
| Foundation | One `AGENTS.md`, one instruction file | `AGENTS.md` is the clan law. No `.github/copilot-instructions.md`. Lean-ctx was pasted three times and the copies disagreed. |
| Specialists | A few role files | Roles were prose in `AGENTS.md`. No `.github/agents/`. |
| Capabilities | Skills for repeated work | None in git. The Grok skill pack for the session lives outside the repo. |

## Grok surfaces

| Surface | Use on Thunderstone |
|---|---|
| Grok Build `AGENTS.md`, worktrees, plan mode | Keep. This repo is that surface. |
| Grok Bot skills, routines, approvals | Clan roles. Do not add a second orchestrator. |
| grok.com connectors | Native GitHub and Drive. Custom MCP only for `https://docs.x.ai/api/mcp`. |
| xAI API and Collections | Off. No key in the starter. |

Session skills that belong in a routing note, not in the starter tree: `grok-agent-ops`, `lean-ctx`, `cavecrew`, `skill-catalogue-retriever`, `composio` (discover only). Leave `database-engineering`, `hybrid-rag`, and `obda-data-contract` off this repo until a product repo has a query.

## Use these, ignore the rest

From `modme-ui-01`. Prefer these paths over the awesome-copilot mirror.

| Keep as a pointer | Why |
|---|---|
| `.cursor/skills/architect` | Types and module seams before any new file. |
| `.github/agents/adr-generator.agent.md` | The missing artifact was a control-plane ADR. |
| `.github/agents/se-system-architecture-reviewer.agent.md` | Reliability and ops only. Not scale, not a cache. |
| `.github/agents/github-actions-expert.agent.md` | CI is already the real gate. |
| `.github/agents/se-security-reviewer.agent.md` | Pairs with `scripts/check-hygiene.sh`. |
| awesome-copilot `agent-governance-reviewer.agent.md` | Fits a clan. Read-only review. |
| awesome-copilot `context-architect.agent.md` | One lean-ctx rule, not three. |

Do not import: `speckit.*` (it writes `.specify/memory/constitution.md` and would become a third constitution beside `AGENTS.md` and `config/clan.yaml`), `gem-orchestrator` (fan-out; clan law is one owner and no recursive agent), `postgresql-dba`, `neon-*`, `database-specialist`, `master-data-architect`, React and Next agents, and every Beast Mode file. Those are the product plane or the opposite of lean-ctx.

## Changes, in order

Status is against branch `docs/catalogue-mcp-adr`.

1. **Collapse lean-ctx to one contract.** On main, `AGENTS.md` pointed at `LEAN-CTX.md`. `.cursorrules` said never use a native read. `.cursor/rules/lean-ctx.mdc` said shadow mode and native edit are fine, and it was `alwaysApply` with a 100-token cap. That cap fights the clan report (outcome, files, checks, blocker, next) and any ADR. **Done on this branch:** shadow-mode rule kept, duplicate mandatory mapping removed, token budget removed. `lean-ctx setup` can restore the budget. If it does, delete that block again.

2. **Fix the worktree rule.** On main, `.cursor/rules/multi-agent-worktrees.mdc` had two steps numbered 3, and step 2 never gave the `git worktree add` command. **Done on this branch:** one numbered list and one command. Still no push to `main`.

3. **Add the control-plane ADR. Do not add a database.** **Done:** `docs/adr/adr-0001-control-plane.md`, status Proposed. Drive owns knowledge, GitHub owns promoted scripts, Cursor runs briefs, retrieval stays out. Redis, Postgres, LanceDB, and Collections are rejected on this repo.

4. **One Copilot foundation file, five pointers.** **Done:** `.github/copilot-instructions.md` distilled from `AGENTS.md`. Pointers, not copies, for adr-generator, se-system-architecture-reviewer, github-actions-expert, se-security-reviewer, and agent-governance-reviewer. The 61-file tree and the 200-file tree are not in this repo.

5. **Connector examples, not a live secret blob.** **Done:** `config/mcp/xai-docs.http.json` points at `https://docs.x.ai/api/mcp`. GitHub stays the native connector. No Supabase URL. `.cursor/mcp.json` is not committed.

6. **Do not land the docs-import PR until its path findings are fixed.** That PR is separate. This evaluation does not merge it and does not rewrite it. Absolute paths in health and startup scripts fail this repo's own hygiene rule.

7. **No new skill in the Grok pack.** A `thunderstone-control-plane` skill would restate `AGENTS.md`. Not created.

## Catalogue MCP

The portable catalogue is the official Awesome Copilot MCP, not a checked-in tree.

| Fact | Value |
|---|---|
| Server | `io.github.microsoft/awesome-copilot` |
| Image | `ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot:latest` |
| Tools | `search_instructions`, `load_instruction` |
| Prompt | `get_search_prompt` |
| Indexed repo | `github/awesome-copilot` |
| Shared public URL | none |

Microsoft ships it as Docker. Stdio is the default. `--http` serves loopback port 8080. A community npm server (`awesome-copilot-mcp`) is also local-only, so this repo uses the official image. Bootstrap does not install Docker. `scripts/awesome-copilot-mcp.sh` starts the image only when Docker is already present, bound to loopback. Do not paste that URL into grok.com. A public host would be a separate decision (the Microsoft sample can be deployed to the operator's own Azure Container Apps). This repo does not publish one.

`modme-ui-01` `.github/agents` and `mcapp-ai-starter` `consolidated_sources/awesome-copilot` stay mirrors. Read them only if the MCP is down.

## Consequences

- The starter cannot drift from upstream agent text, because it does not store that text.
- grok.com still cannot see the catalogue until someone deploys a public HTTPS host. That is recorded as a negative, not done here.
- CI stays an infrastructure check.

## References

- `docs/adr/adr-0001-control-plane.md`
- `docs/mcp/CATALOGUE.md`
- `AGENTS.md`
- Microsoft sample: `microsoft/mcp-dotnet-samples` path `awesome-copilot`
- Maintained mirror: `Ditto190/modme-ui-01` `.github/agents`
- Upstream dump: `Ditto190/mcapp-ai-starter` `consolidated_sources/awesome-copilot`
