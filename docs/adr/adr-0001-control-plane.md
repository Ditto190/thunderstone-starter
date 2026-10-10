---
title: "ADR-0001: Thunderstone stays a control plane"
status: "Proposed"
date: "2026-10-11"
authors: "DT"
tags: ["architecture", "decision"]
supersedes: ""
superseded_by: ""
---

## Status

**Proposed**

## Context

`thunderstone-starter` is the VM and Cursor control plane for the Thunderstone clan.
Drive owns knowledge. GitHub owns promoted scripts. Cursor runs briefs.
The repository has no application schema. Catalogue copies in other account repos
(`modme-ui-01` `.github/agents`, `mcapp-ai-starter` `consolidated_sources/awesome-copilot`)
are large specialist trees for product work.

## Decision

Keep this repository a control plane.

- **POS path:** agents, skills, and instructions are loaded from the official Awesome Copilot MCP (`search_instructions`, `load_instruction`). Five pointer files under `.github/agents/` name the roles this repo may load. They do not vendor upstream bodies.
- Retrieval stores (LanceDB, xAI Collections, Postgres, Redis) stay out until a product repository has a query that needs one.
- Docker is optional. `scripts/bootstrap.sh` does not install it. `scripts/awesome-copilot-mcp.sh` starts the official image only when Docker is already present.

## Consequences

### Positive

- **POS-001**: The starter cannot drift from upstream agent text.
- **POS-002**: CI stays an infrastructure check, not an application build.
- **POS-003**: Grok, Cursor, and Copilot share one catalogue server instead of three checked-in trees.

### Negative

- **NEG-001**: The catalogue MCP is not usable without Docker, or without a host the operator deploys. There is no shared public URL.
- **NEG-002**: Loopback HTTP is invisible to grok.com. A public host is a separate, explicit decision.
- **NEG-003**: `lean-ctx setup` can restore generated rule text that this ADR says is not clan law.

## Alternatives Considered

### Copy the catalogues

- **ALT-001**: **Description**: Commit the modme agent tree or the awesome-copilot tree.
- **ALT-002**: **Rejection Reason**: Two large trees, immediate drift, wrong archetype.

### Add Redis or Postgres here

- **ALT-003**: **Description**: Start a cache or OLTP schema in this repo.
- **ALT-004**: **Rejection Reason**: No consumer query. Store choice belongs to a product repo.

### Do nothing

- **ALT-005**: **Description**: Leave conflicting lean-ctx rules and no ADR.
- **ALT-006**: **Rejection Reason**: Agents follow whichever copy they open first.

## Implementation Notes

- **IMP-001**: Pointers live in `.github/agents/`. Routing notes live in `docs/mcp/CATALOGUE.md`.
- **IMP-002**: Do not merge this ADR's idea into PR branches that still hardcode absolute paths.
- **IMP-003**: Success is `npm test` plus a Docker host where `search_instructions` returns a hit without a new file in this repo.

## References

- **REF-001**: `AGENTS.md`, `config/clan.yaml`
- **REF-002**: Microsoft Awesome Copilot MCP, image `ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot`
- **REF-003**: `Ditto190/modme-ui-01` `.github/agents` (maintained pointers, not a second copy)
