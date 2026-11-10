# Pattern: modular monolith boundary

Status: Proposed. Use for NEW services/new deploy units where one deployment can meet agreed requirements and capability ownership needs clearer boundaries. Existing systems conform through documented exceptions and accepted architecture, not forced restructuring.

## When not to use — existing-topology carve-outs

- **ModMe:** do not apply this pattern to merge the federated `next-forge/` and `GenerativeUI_monorepo/` workspaces or collapse accepted ADR-0010's GreptimeDB `code_index` + Supabase `inbox_entries`. Existing monorepo separation and dual-store ownership are documented applicability exceptions. No cross-monorepo `workspace:*` or relative private imports. [ModMe monorepo rule](/workspace/modme-ui-01/.cursor/rules/monorepo-boundaries.mdc#L8); [ModMe accepted ADR-0010](/workspace/modme-ui-01/next-forge/docs/adr/0010-dual-store-knowledge-intake.md#L3).
- **Starter:** do not create a `src/` product tree for the Drive-first tooling kit; preserve `scripts/` and `.cursor/hooks/`. Its inspected root has no `src/`. [Starter AGENTS.md](/workspace/thunderstone-starter/AGENTS.md#L3); [local tree](/workspace/thunderstone-starter/).
- Existing accepted multi-deploy/multi-store decisions take precedence until separately reviewed and superseded with explicit approval; this pattern grants no migration authority. Maintain ModMe's [existing C4 views](/workspace/modme-ui-01/C4-Documentation/c4-container.md).

## Problem

Premature distributed deployment adds moving parts before an independent scaling need is demonstrated. Proposed response: start with one deployment and explicit logical separation. Microsoft's guide describes a single application as the simplest deployment model while retaining logical layers. [Official architecture guide](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures).

## Context

Small team, constrained operating budget, shared data consistency needs. Proposed default for a NEW deploy unit only: one app and database; set numeric SLO/load/budget in the framework first. C4 provides context/container/component views without prescribing a deployment technology. [C4](https://c4model.com/).

## Solution

- Capability folders own domain logic and writes. Export public interfaces; disallow callers importing private code or writing another capability's tables. This stricter import policy is our design, not a statement from C4. [Logical separation](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures).
- Keep capability interaction in-process initially. Split only when measurement shows an isolation/scaling/ownership benefit worth extra operations. Record the decision and reversal conditions. [Single deployment trade-offs](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures); [Decision rationale](https://adr.github.io/).

## Trade-offs

One release/rollback remains coupled; boundaries can erode without tests. Independent scaling is limited to whole-app replication until extraction. Logical modules reduce neither failure scope nor cost automatically. Microsoft's guide discusses monolith scaling and layered organisation. [Trade-offs](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures).

## Official source

Fetched 10 November 2026 AEDT: [Microsoft](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures): “This approach is the simplest deployment model”. [C4](https://c4model.com/): “A set of hierarchical abstractions”.

## Example

Greenfield illustration only — this `src/` tree is not either existing repository's layout:

```text
src/
  orders/public/       # approved interface
  orders/internal/     # only orders may import
  billing/public/
  billing/internal/
tests/boundaries/      # import allow-list fixtures
```

The directory names and tests are proposed; no implementation is implied.

## Test

Not run — draft. Specify a static import-rule fixture: a permitted `billing -> orders/public` reference passes; `billing -> orders/internal` fails. Add a data-access test proving billing cannot mutate order-owned records through its public interface. Fresh checkout must pass the documented repo check command; choose the actual language/tool in SWE review. For any later ModMe boundary-test work, preserve Bun/Yarn workspace boundaries and the agent-server ports/adapters layout; do not point a single-root `src/` linter at both monorepos. [ModMe architecture](/workspace/modme-ui-01/docs/codebase/ARCHITECTURE.md#L35). Source basis: logical separation and explicit ADR consequences, not a vendor-supplied test. [Separation](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures); [Consequences](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions).
