# Twelve-factor agents — adapted operating draft

**Attribution and licence notice:** adapted from *The Twelve-Factor Manifesto*, Twelve-Factor contributors, [twelve-factor/twelve-factor](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/README.md), commit `3ad5a5f36312cc8ad876abae1bd691acd790d4d1`. Original methodology: Adam Wiggins, credited in the [12factor.net](https://12factor.net/) page metadata/footer. Upstream repository material is licensed **Creative Commons Attribution 4.0 International (CC BY 4.0)**: [unaltered upstream LICENSE](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/LICENSE); [licence summary](https://creativecommons.org/licenses/by/4.0/). Full licence is retained at `/workspace/vendor/twelve-factor/LICENSE`, including its disclaimer of warranties; upstream material is provided as-is. This adaptation is modified, unofficial and not endorsed by upstream. It does not relicense project code or the separately hosted 12factor.net website.

Status: Proposed; local draft only. Adapted 10 November 2026 AEDT for Grok Bot's persistent shared box, Cursor CLI/cloud agents, Origin/GitHub. Headings and upstream intent retained; examples rewritten, security/approval constraints and tests added. Per-factor paths below are relative to the pinned clone. The upstream README calls this an updated manifesto with ongoing work on `next`; the clone checked out its default branch, `next`. This draft pins that in-progress snapshot, not a claim of a final accepted revision. [Upstream update status](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/README.md).

## Scope and deliberate differences

- **Authoring vs runtime:** the box's shared filesystem persists; cloud agents use isolated VMs. Persistence is useful for authoring evidence, not a guarantee that runtime workers share state. [Cloud runtime](https://cursor.com/docs/cloud-agent.md); [Stateless runtime](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/processes.md).
- **Config:** env/secret stores, no secret values in repo or evidence. Secret-store injection/redaction are our extensions to upstream environment config. [Upstream III](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/config.md).
- **Event-only:** no new cron, schedules or time-based routines. Existing schedules require documented conversion or a separate explicit owner-approved bounded waiver; none is granted here. See the [nine-workflow inventory](PATTERN-config-env-event-only-hooks-20261110.md#existing-scheduled-estate--proposed-event-replacements). This is a DT constraint, not an upstream factor; Origin offers schedules as well as events and we intentionally use only events. [Triggers](https://cursor.com/docs/origin/agents.md); [Hooks](https://cursor.com/docs/hooks.md).
- **Approvals:** source principles do not authorise commit/push/merge/delete/send/spend. No new paid Grok API dependency: existing [ADR-0001](ADR-0001-model-routing-via-litellm.md) stays Proposed. These local constraints override any vendor example that would write automatically.
- All gates below are proposed tests, **not executed**. Host/CLI/cloud configuration must be verified in the actual environment before adoption. [Runtime configuration](https://cursor.com/docs/cloud-agent.md); [Hook support](https://cursor.com/docs/hooks.md).

## Hook schema and cloud-runtime qualification

Use the documented project object shape `{"version":1,"hooks":{...}}` and per-script `timeout` in seconds — **not `timeoutSec`**. Cloud agents must not depend on `sessionStart`: it is unavailable in cloud agents, and no hooks run in their early read-only turns. Supported `beforeSubmitPrompt`/`afterFileEdit`/`stop` can cover validation/edit checks/completion evidence once writable; a reviewed task-entry bootstrap and CI/approval gates remain necessary before writes. Self-hosted Pools/My Machines fire `sessionStart` on worker claim and are a separate case. [Official hook schema and runtime matrix](https://cursor.com/docs/hooks.md).

Starter currently uses a valid `sessionStart` stage-router with `timeout: 5`; its cloud path needs an explicit supported alternative rather than assumed lifecycle parity. ModMe's active hook file is `[]` and its example uses `timeoutSec`; record these as configuration gaps, **do not copy or silently repair the live files** in this docs task. See [proposed valid JSON and tests](PATTERN-config-env-event-only-hooks-20261110.md#official-hook-schema-and-runtime-gate); [Starter hooks](/workspace/thunderstone-starter/.cursor/hooks.json); [ModMe active hooks](/workspace/modme-ui-01/.cursor/hooks.json); [ModMe example](/workspace/modme-ui-01/.cursor/hooks.json.example).

**Existing architecture is retained:** NEW services use the framework's default; ModMe keeps independent Bun/Yarn monorepos and accepted ADR-0010 dual-store, while the starter remains a tooling kit without `src/`. Conform through documented applicability exceptions, not forced consolidation. [Monorepo rule](/workspace/modme-ui-01/.cursor/rules/monorepo-boundaries.mdc#L8); [Accepted dual-store ADR](/workspace/modme-ui-01/next-forge/docs/adr/0010-dual-store-knowledge-intake.md#L3); [Starter ownership](/workspace/thunderstone-starter/AGENTS.md#L3).

## I. Codebase

Upstream: `content/codebase.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/codebase.md). Intent: “One codebase tracked in revision control, many deploys”.

- **Box:** Treat each app/deployable as one versioned codebase. Keep one forge of record; box workspaces/branches are working copies, not extra production sources.
- **Cursor CLI/cloud:** Pass an immutable commit and bounded brief to CLI/cloud work. Cloud work is not a deploy unless explicitly released.
- **Origin/GitHub:** Pick Origin-hosted or GitHub-authoritative. A GitHub-to-Origin mirror is a replica, not dual authority.
- **Proposed gate / adaptation:** Evidence records app identity, commit, release and forge. Monorepo grouping of independently deployable apps is a documented local extension, not literal one-app/one-repo compliance.

## II. Dependencies

Upstream: `content/dependencies.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/dependencies.md). Intent: “Explicitly declare and isolate dependencies”.

- **Box:** Do not depend on accidental tools installed on the persistent shared box. Declare runtime, system tools and dependency versions in manifests/image setup.
- **Cursor CLI/cloud:** Use the same lockfiles and declared setup for fresh CLI and cloud environments; retain the small verification-lane set appropriate to each deploy unit (`npm test` for starter, `yarn verify:forge` / `yarn verify:generative` for ModMe); test bootstrap without a global cache. [Starter scripts](/workspace/thunderstone-starter/package.json); [ModMe lanes](/workspace/modme-ui-01/AGENTS.md#L29).
- **Origin/GitHub:** Store manifests/setup in the authoritative repo; CI consumes pinned revisions, not whichever global tool happens to exist.
- **Proposed gate / adaptation:** Fresh isolated setup can run the verification command. Image-pinned system tools are our equivalent to upstream vendoring; record any portability gap.

## III. Config

Upstream: `content/config.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/config.md). Intent: “Store config in the environment”.

- **Box:** Keep deploy-specific handles/config in environment variables or approved secret stores. Never put credential values in the repo, brief, prompt, artifact or log.
- **Cursor CLI/cloud:** Inject config into each authorised runtime independently. Missing config fails closed, with names only in diagnostics; a box env var is not automatically a cloud secret.
- **Origin/GitHub:** Code host/CI secret stores supply runtime config through approved mechanisms; no secret values in code-host files or copied between hosts by this task.
- **Proposed gate / adaptation:** Schema/names may be committed later with approval; values never. Store injection/redaction are local security extensions; env vars alone do not secure a secret.

## IV. Backing services

Upstream: `content/backing-services.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/backing-services.md). Intent: “Treat backing services as attached resources”.

- **Box:** Name durable DB, queue, object storage and any approved model endpoint as attached resources. Do not equate a scratch directory with a durable shared service.
- **Cursor CLI/cloud:** Workers receive resource handles through runtime config and documented adapters; resource lifecycle is separate from worker lifecycle.
- **Origin/GitHub:** Host choice does not change data ownership. Store endpoint names/schema in code and credentials only in the authorised runtime store.
- **Proposed gate / adaptation:** Swap a compatible test resource via config, without code edits; document data migration/protocol compatibility rather than promising every backend is interchangeable.

## V. Build, release, run

Upstream: `content/build-release-run.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/build-release-run.md). Intent: “Strictly separate build and run stages”.

- **Box:** Build from a pinned revision, combine approved config into an identified immutable release, then run. No live patching of a running release.
- **Cursor CLI/cloud:** Agent code edits belong to authoring workspaces, not a mutable production release. Record artifact/revision and test evidence before handoff.
- **Origin/GitHub:** Forge records revision; CI builds/tests; release approval is separate from an agent finishing a patch. A code-host push is not deployment approval.
- **Proposed gate / adaptation:** Each release ID maps to one artifact/config reference; rollback selects a previous release. Never embed secret values in release evidence.

## VI. Processes

Upstream: `content/processes.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/processes.md). Intent: “Execute the app as one or more stateless processes”.

- **Box:** The box is persistent and shared, but runtime correctness must not rely on a previous process memory/scratch file. Put durable facts/checkpoints in an owned backing service.
- **Cursor CLI/cloud:** CLI/cloud workers may be replaced. Treat local caches as disposable; publish explicit artifacts/checkpoints for the next worker.
- **Origin/GitHub:** Repos hold code/contracts, not live coordination state or secrets. Use a separate durable store for request results/deduplication.
- **Proposed gate / adaptation:** Restart/recreate a worker and replay its event without lost committed state or duplicate mutation. Persistent authoring files are an explicit scope exception, not a stateless runtime claim.

## VII. Port binding

Upstream: `content/port-binding.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/port-binding.md). Intent: “Export services via port binding”.

- **Box:** A network service owns its bound port and health/readiness contract. A pure one-off CLI task need not listen on any port.
- **Cursor CLI/cloud:** Bind only the approved interface in the actual runtime; a service in a cloud VM is not automatically reachable from the box.
- **Origin/GitHub:** Origin/GitHub store service configuration/code; neither code host substitutes for a service runtime or makes a local port public.
- **Proposed gate / adaptation:** Service startup/readiness tested on its configured port; CLI-only work records N/A. Port exposure, TLS and access policy need a separate runtime design.

## VIII. Concurrency

Upstream: `content/concurrency.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/concurrency.md). Intent: “Scale out via the process model”.

- **Box:** Separate web/check/worker process types only when useful. Bound concurrency/resources; rely on the execution environment, not self-daemonising scripts or PID files.
- **Cursor CLI/cloud:** Dispatch bounded work from supported lifecycle/source-control events. No cron, scheduled automation, timer polling or time-based routines: local DT overlay, not upstream wording.
- **Origin/GitHub:** Origin documents push/PR/label automation triggers as well as schedules; adopt event triggers only. Any GitHub workflow design must apply the same no-schedule rule.
- **Proposed gate / adaptation:** Record process/queue limits and an allowed event; reject new scheduled trigger configuration. Legacy schedules remain explicit gaps until conversion or a separately approved bounded waiver; no waiver is implicit in this adaptation. Do not infer automatic autoscaling or unlimited cloud workers.

## IX. Disposability

Upstream: `content/disposability.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/disposability.md). Intent: “Maximize robustness with fast startup and graceful shutdown”.

- **Box:** Keep startup short; on graceful stop, stop accepting work then finish or safely return/checkpoint it. Recover from abrupt termination too.
- **Cursor CLI/cloud:** Use bounded task timeouts and durable event identities; releasing a worker is safe only when unfinished work can be recovered.
- **Origin/GitHub:** Store code/release identity in the forge and recovery state outside disposable worker storage. A pushed branch alone is not a runtime checkpoint.
- **Proposed gate / adaptation:** SIGTERM and crash/replay tests do not lose acknowledged writes or repeat side effects. Numeric readiness/stop targets require an agreed SLO.

## X. Dev/prod parity

Upstream: `content/dev-prod-parity.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/dev-prod-parity.md). Intent: “Keep development, staging, and production as similar as possible”.

- **Box:** Minimise runtime/tool/service version differences across the box, test and production; do not silently substitute a different database dialect.
- **Cursor CLI/cloud:** Use the same dependency locks, documented per-deploy-unit verification lane set and service versions in CLI and cloud images where practical; record architecture/network/permission gaps.
- **Origin/GitHub:** Run equivalent tests against the same revision on either host. “Same checks” means equivalent test inputs/semantics, not merely matching check names.
- **Proposed gate / adaptation:** Parity matrix lists versions and justified gaps. Upstream deployment cadence is not permission to bypass DT release approval; prod credentials/data never copied to development.

## XI. Logs

Upstream: `content/logs.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/logs.md). Intent: “Treat logs as event streams”.

- **Box:** Processes emit time-ordered stdout events; the runtime collector handles routing, storage and retention. No application-managed log rotation.
- **Cursor CLI/cloud:** Use redacted structured events with task/release/correlation ID; keep raw sensitive prompts and credentials out. Artifacts reference evidence, not secret-bearing streams.
- **Origin/GitHub:** CI/agent collectors may retain streams under their access policy; a git repository is not the log sink. Review retention/access before enabling a collector.
- **Proposed gate / adaptation:** Capture/replay stdout without a required local logfile. JSON encoding, redaction and field names are our additions; upstream requires streams, not a specific format.

## XII. Admin processes

Upstream: `content/admin-processes.md` — [pinned source](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/content/admin-processes.md). Intent: “Run admin/management tasks as one-off processes”.

- **Box:** Run migrations, repairs and audits as explicit one-off CLI tasks against the selected release/config; not hidden recurring jobs.
- **Cursor CLI/cloud:** Use the same code/dependency isolation as normal processes. Name scope, dry-run, expected effect, rollback and approval in the brief.
- **Origin/GitHub:** Host/CI can store the task code and evidence but does not grant authority to run it on live data. Commit/push/delete/send/spend retain their separate approvals.
- **Proposed gate / adaptation:** Release-matched dry-run/fixture and bounded execution evidence required before live writes. No administrative task was run by this document.

## Traceability and adoption

This is a semantic adaptation, not an edit to the vendor clone. No factor is silently removed. Where CLI authoring or monorepo packaging differs from service-runtime assumptions, the difference is explicit. Full factor-by-factor change notes and citation self-check: `/workspace/thunderstone/artifacts/ARCH-FRAMEWORK-RESEARCH-20261110.md`.

Use [framework section 5](ARCH-FRAMEWORK-20261110.md#5-scaling-path--adapted-twelve-factor-basis) as the new-service gate and [env/event pattern](PATTERN-config-env-event-only-hooks-20261110.md) for the first reusable application. Promote only after design and independent licence/citation review. Upstream licence requires attribution and a modification notice when sharing adapted material; retain both before any later publication. [Licence section 3](https://raw.githubusercontent.com/twelve-factor/twelve-factor/3ad5a5f36312cc8ad876abae1bd691acd790d4d1/LICENSE); [CC BY conditions](https://creativecommons.org/licenses/by/4.0/).
