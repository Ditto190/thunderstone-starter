# Pattern: environment config and event-only hooks

Status: Proposed. Use for an agent task/service that needs deploy-specific configuration or lifecycle/source-control triggers. Basis: [adapted twelve-factor](TWELVE-FACTOR-AGENTS-20261110.md), factors III, VIII, IX, XI and XII.

## Problem

Config mixed with code obstructs deploy portability and risks credential exposure. Repeated scheduled work also violates this project's event-only constraint. The config principle is upstream; the no-cron rule is explicitly our overlay. [Upstream config](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/config.md); [Product offers event and scheduled triggers](https://cursor.com/docs/origin/agents.md).

## Context

Grok Bot's persistent shared box plus separate Cursor cloud VMs; Origin or GitHub as forge of record. Never assume box environment variables or global skills appear in cloud workers. Cloud isolation and skill sync are documented separately. [Cloud environment](https://cursor.com/docs/cloud-agent.md); [Skill distribution](https://cursor.com/docs/skills.md).

## Solution

- Keep config schema/names in code, never secret values. Inject deploy-specific config via environment variables or an approved secret store at runtime; redact errors and outputs. Env is a transport, not a credential vault. [Separation and env config](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/config.md).
- Use supported lifecycle/tool hooks or source-control push/PR events. Cloud agents must not depend on `sessionStart` (unavailable in the official matrix). No NEW cron, timer schedule, recurring polling or scheduled automation. Existing scheduled jobs require the explicit inventory/owner decision below; no waiver is granted by mentioning them. Products offering schedules does not override this local rule. [Hook events/runtime matrix](https://cursor.com/docs/hooks.md); [Push/PR/label events](https://cursor.com/docs/origin/agents.md).
- Run a bounded handler in the foreground; use durable event deduplication and recover interrupted work. Stream logs; use one-off release-matched CLI tasks for admin. [Process management](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/concurrency.md); [Shutdown](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/disposability.md); [Streams](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/logs.md); [Admin](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/admin-processes.md); [Deduplication](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/).

## Trade-offs

Event delivery can be duplicated or delayed, so handlers need replay safety. Disabling schedules means no unattended periodic reconciliation: propose an explicit event or approved one-off audit instead. Hook coverage differs across runtimes and is not a standalone permission system. [Retry safety](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/); [Support matrix](https://cursor.com/docs/hooks.md).

## Official source

Fetched 10 November 2026 AEDT: [Config](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/config.md): “Store config in the environment”. [Admin](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/admin-processes.md): “Run admin/management tasks as one-off processes”. [Origin](https://cursor.com/docs/origin/agents.md): “Push to branch” is a documented trigger. The ban on cron is not attributed to twelve-factor.

## Example

Pseudocode, not installed:

```text
trigger: repository pull-request updated event
required config names: MODEL_ENDPOINT, DATABASE_CONNECTION
secret source: approved runtime secret store (values never in this file)
handler: validate event -> deduplicate -> bounded check -> stream outcome
admin: explicit one-off CLI task against a named release
```

Do not use `sessionStart` as a cloud dependency: it is unavailable, not just late. Use a reviewed explicit task bootstrap and cloud-supported validation/edit/completion hooks as below. [Cloud hook matrix](https://cursor.com/docs/hooks.md).

## Official hook schema and runtime gate

`timeout` is the per-script field, in **seconds**; `timeoutSec` is not the documented key. Cloud agents do not run `sessionStart` at all under the fetched matrix, and no hooks run in their early read-only turns. `beforeSubmitPrompt`, `afterFileEdit` and `stop` are supported once writable. Self-hosted Pools/My Machines do fire `sessionStart`/`sessionEnd` on worker claim/release; this is a different runtime. [Official schema and runtime matrix](https://cursor.com/docs/hooks.md).

Proposed schema example only; the named script is not installed or executed:

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {"command": ".cursor/hooks/check-policy.sh", "timeout": 5, "failClosed": true}
    ]
  }
}
```

A task-entry preflight before any write plus CI/DT approval remains necessary; a prompt hook is not guaranteed to run before exploratory turns, and `stop` is evidence collection, not a pre-action gate. Starter currently routes stages at `sessionStart` using valid `timeout: 5`; propose a cloud-supported validation/explicit entrypoint path, **not** blind movement to an after-the-fact hook. ModMe's current `.cursor/hooks.json` is `[]`, and its example uses `timeoutSec`; do not copy either as a valid project hook configuration. These live files are unchanged by this review. [Starter hook config](../../.cursor/hooks.json); [ModMe active config](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.cursor/hooks.json); [ModMe example](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.cursor/hooks.json.example); [Expected version/hooks object](https://cursor.com/docs/hooks.md).

## Existing scheduled estate — proposed event replacements

Read-only snapshot, 10 November 2026 AEDT: ModMe HEAD `5dbdc39f8a0012ea4b05dfa20852eec165ec5b60` (45 Actions YAML files), starter HEAD `35646d45eca7932d8bc8abc5b8b26315adcb0bb6` (5). A recursive `schedule:` search found **8 scheduled ModMe YAML workflows, not 8 CodeQL workflows**, plus starter's CodeQL: **9 executable YAML definitions total**. Only one of the eight ModMe names is `codeql.yml`. This counts file definitions, not live enabled workflows or runs. Sources: each file/line below; machine inventory schedules.json: Thunderstone evidence arch-framework-swe-sources-20261110/schedules.json (ops artifact, outside this repository).

Raw cron strings are quoted configuration, not converted appointment times. Proposals use documented event types, but need fixture/security/coverage review and DT's explicit approval before any change. **No waiver is approved; no workflow or schedule was edited/disabled.** Existing schedules remain recorded policy divergences, not proof of conformance. If event conversion cannot preserve a required security/freshness guarantee, request a narrowly scoped, owner/time-bounded waiver with compensating checks; do not invent its approval. [Event/dispatch/workflow semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows); [Event-only overlay also applies to Origin](https://cursor.com/docs/origin/agents.md).

| Repo / workflow source | Raw cron | Event-based replacement proposal (not implemented) | Waiver / decision |
| --- | --- | --- | --- |
| [modme-ui-01/agentics-maintenance.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/agentics-maintenance.yml#L37) | `37 0 * * *` | Generated expiry-maintenance file: change the owning gh-aw generator/expiry configuration, not generated YAML in isolation. Propose bounded maintenance after workflow/output changes plus explicit human dispatch for expiry audit; idle-time expiry coverage is lost without a separately approved control. | None; DT decision pending |
| [modme-ui-01/ai-assisted-maintenance.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/ai-assisted-maintenance.yml#L4) | `0 9 * * 1` | Path-filtered PR/approved-merge changes and explicit workflow_dispatch for each requested maintenance operation; owner chooses coverage formerly provided by the periodic audit. | None; DT decision pending |
| [modme-ui-01/build-code-index.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/build-code-index.yml#L49) | `0 2 * * *` | Use relevant source-change PR/approved-merge events and explicit workflow_dispatch for full reindex; correct path scope for preserved Bun/Yarn topology, bound deduplication and backlog. | None; DT decision pending |
| [modme-ui-01/codeql.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/codeql.yml#L19) | `43 17 * * 1` | Retain PR and approved-merge push-triggered scans; propose explicit human dispatch or an approved dependency/security-advisory event handler for rescans without code changes. Review CodeQL/security coverage before removing the periodic scan. | None; DT decision pending |
| [modme-ui-01/journal-code-index.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/journal-code-index.yml#L36) | `0 3 * * 0` | Relevant source-change events for incremental indexing; explicit workflow_dispatch for full rebuild/recovery. Preserve durable checkpoint/replay behaviour and correct per-workspace paths. | None; DT decision pending |
| [modme-ui-01/output-generate.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/output-generate.yml#L4) | `0 6 * * *` | Explicit workflow_dispatch or authenticated repository_dispatch after intake/promotion completion, with event-ID deduplication and DT approval before generated output writes. | None; DT decision pending |
| [modme-ui-01/toolset-docs.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/toolset-docs.yml#L9) | `0 0 * * 0` | Keep the existing toolset-update/deprecation workflow_run completed events plus workflow_dispatch; review trusted-source/success filtering and recursion before removing schedule. | None; DT decision pending |
| [modme-ui-01/workflow-health.lock.yml](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/workflow-health.lock.yml#L53) | `9 16 * * 3` | Change workflow-health.md source frontmatter, then recompile/test the generated lock. Propose bounded workflow_run completion/failure and workflow-definition-change checks, excluding self-recursion; explicit dispatch for wider audit. | None; DT decision pending |
| [thunderstone-starter/codeql.yml](../../.github/workflows/codeql.yml#L6) | `17 3 * * 1` | Retain PR and approved-merge push scans; propose explicit human dispatch/security-advisory event re-scan for new query/advisory coverage. Owner approves coverage impact before removing schedule. | None; DT decision pending |

Two additional non-executable schedule-bearing files were found: [workflow-health.md authoring source](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/workflow-health.md#L4) (`schedule: weekly`, feeds the generated lock above) and [build-code-index.yml.archived](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/.github/workflows/build-code-index.yml.archived#L49) (archived config). Do not count them as extra runnable YAMLs or re-enable them. Remove/change the authoring schedule only under the same approved conversion plan; keep the archive inert. ModMe architecture's “Cron, health, integrations” wording is also a documented legacy gap, not permission for new schedules. [Existing API responsibility text](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/docs/ARCHITECTURE.md#L39).

## Test

Not run — draft. Missing config fails closed without printing values; secret scanning rejects value-bearing fixtures; static config check rejects NEW scheduled triggers/cron and reports each inventoried legacy job as an unresolved decision (not a silent pass); hook-schema fixtures reject `[]`/`timeoutSec`, accept the documented `timeout` form, and reject cloud reliance on `sessionStart`; one PR event starts one bounded handler; duplicate/replayed event causes no duplicate write; SIGTERM returns/recoverably checkpoints unfinished work; stdout contains redacted structured events. Tests are local acceptance criteria derived from [config](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/config.md), [disposability](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/disposability.md) and [idempotency](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/), not completed implementation.
