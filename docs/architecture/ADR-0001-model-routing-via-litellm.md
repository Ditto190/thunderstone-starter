# ADR-0001: Route models through LiteLLM (or similar harness); no paid Grok API

> Included in this repository so in-repo links from ADR-0002 and the twelve-factor draft resolve. Status remains **Proposed**. Promoted from the Thunderstone drafts inventory (outside this repository) on 13 November 2026.


## Status

**Proposed** (decision stated by DT on 2026-10-11; pending review and merge). Board: Project #2 Thunderstone.

## Context

- DT will not use the xAI Grok API: it requires paid API credit.
- DT prefers self-hosted or locally controlled tooling and cost-efficient agent work (standing preferences).
- Agents on the shared VM need one model entry point that can reach hosted models DT already pays for, local models run on the VM, and models reached through the Zed editor.
- Thunderstone work (agent selection patterns, dynamic selection toolkit, event hooks) needs a stable, provider-neutral model interface.

## Decision

1. Do not depend on the xAI Grok API in Thunderstone code, scripts, CI or docs. Remove any `XAI_API_KEY`-style requirement from `.env.example`/docs (names only; no values anywhere).
2. Use a single OpenAI-compatible routing layer, LiteLLM proxy by default (or an equivalent harness if one proves lighter), as the only model endpoint agents and scripts call.
3. Back it with: (a) models DT already has access to, (b) local models on the VM (for example via Ollama or llama.cpp servers), (c) Zed-provided or Zed-configured models where Zed exposes an endpoint.
4. Selection patterns (item #13) and the dynamic selection toolkit (#15) target model aliases defined in the router config, never provider-specific names.
5. Grok Bot as an app/chat is unaffected by this ADR; it concerns programmatic API use only.

## Consequences

- Positive: no new paid API; one place for routing, fallbacks, budgets and logging; provider swaps need no code change; fits the local-first preference.
- Negative: one more service to run and secure on the VM; local model quality and speed vary; the router config becomes a critical file.
- Security: the router binds to localhost only, keys come from environment variable names documented in `.env.example`, no secrets in the repo.

## Open points (unverified, to confirm before Accepted)

- Which Zed integration path is available on the VM (Zed's model endpoint or its agent protocol); not checked yet.
- Which local models and hardware the VM can run.
- LiteLLM vs a lighter harness: decide after a small spike.

## Alternatives considered

- Paid Grok API directly: rejected on cost.
- Per-provider SDK calls in each script: rejected, duplicates config and blocks swapping.
- Beads/Dolt-style layer: unrelated to model routing; not considered.
