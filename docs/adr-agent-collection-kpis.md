# ADR: Agent collection success KPIs

**Status:** Accepted · **Date:** 2026-10-11

See Project store copy: durable KPI list for Cloud Agent Projects. This repo copy is the versioned source of truth for Thunderstone.

## Baseline

One **investigator**, one **implementer**, one **verifier** before adding agents.

## KPIs

Track: time request→validated brief; assignment→accepted patch; context volume per handoff; duplicate launches; rework from stale inputs; failed/missing receipts; recovery after worker interruption; human intervention; publication failures **separate** from implementation failures.

## Pilot gates (deterministic)

1. Interrupted task resumes correctly.  
2. Duplicate receipt ignored.  
3. Failed validation blocks promotion.

Coordination: `tests/agent-collection-invariants.sh` + `.cursor/hooks/state/collection-metrics.jsonl`. Answer quality: research evals where appropriate — not LLM grader or bare tool success.

## Scope

Implement **versioned handoff protocol** (`docs/handoff-protocol.md`) on this starter. RDMA deferred behind model-serving boundary until GPU ops justify it.
