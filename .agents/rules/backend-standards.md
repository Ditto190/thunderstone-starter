---
description: Backend architecture, BFRI risk index, and reliability guidelines
globs: ["**/*.ts", "**/*.js", "**/*.py", "workspace/bridge/**/*"]
always_on: false
---

# Backend Engineering Guidelines

When designing and modifying backend services, APIs, or agent bridge components:

## 1. Backend Feasibility & Risk Index (BFRI)
Before implementing backend modifications, evaluate the BFRI score:
```
BFRI = (Architectural Fit + Testability) - (Complexity + Data Risk + Operational Risk)
```
- **Scale (1 to 5 per dimension):**
  - Architectural Fit: Follows layered architecture (routes $\to$ controllers $\to$ services $\to$ repositories).
  - Testability: Can be unit and integration tested deterministically.
  - Complexity: Number of external systems, branch points, or concurrency constraints.
  - Data Risk: Mutations to persistent stores, state corruption, or migration needs.
  - Operational Risk: Impact on auth, worker bridges, or external API quotas.
- **Action Thresholds:**
  - `6 to 10`: Safe to proceed immediately.
  - `3 to 5`: Add explicit tests and telemetry before merging.
  - `< 3`: Refactor or redesign; do not implement directly.

## 2. Layered Architecture & Error Boundaries
- **No Business Logic in Transport Layers:** HTTP handlers, stdio bridge adapters, and CLI entry points only validate inputs and delegate to domain services.
- **Validation at the Boundary:** Validate all incoming schemas using Zod (TypeScript) or Pydantic/dataclasses (Python).
- **Explicit Error Objects:** Never catch and swallow exceptions. Log with structured context and map domain errors to typed response codes.

## 3. Idempotency & Invariants
- All agent operations, background tasks, and webhook handlers must be idempotent.
- Invariants must be asserted via deterministic tests (e.g. `tests/agent-collection-invariants.sh`), never trusted solely from LLM grading or successful tool return codes.
