# Thunderstone Clan

Drive owns the starter and project intelligence. GitHub owns promoted active code.
Read this file, the assigned brief and current status only.

## Setup
- Run `sh scripts/bootstrap.sh`, then `bash scripts/resume.sh` (Node 22+).
- Copy `.env.example` to `.env.local` and fill values locally. Never commit it.
- Environment loading goes through `scripts/env-run.mjs`; credentials are injected at runtime.

## Commands
- `npm test` runs validation, ShellCheck and `scripts/check-hygiene.sh`.
- `bash scripts/doctor.sh` checks the local environment.
- `bash scripts/cursor-worker.sh status` reports the Cursor My Machines worker (see `docs/grok-vm/cursor-cloud-bridge.md`).
- `ALLOW_LOCAL_COMMITS=1 bash scripts/checkpoint.sh "<message>" <files>` makes a local checkpoint.
- Prefer deterministic CLI tools and APIs over browser clicking.

## Agent collection KPIs
- Baseline collection: one investigator, one implementer, one verifier before adding agents (`docs/adr-agent-collection-kpis.md`).
- Handoff receipts: `docs/handoff-protocol.md`, `scripts/handoff-receipt.sh`; hooks log to `.cursor/hooks/state/collection-metrics.jsonl`.
- Pilot gates: interrupted resume, duplicate receipt ignored, failed validation blocks promotion (`tests/agent-collection-invariants.sh`).

## Boundaries
- One owner per task. Concurrent writers each use their own worktree
  (see `.cursor/rules/multi-agent-worktrees.mdc`). No blind parallel agents.
- Inside Cursor CLI/Cloud, execute directly. Never recursively invoke an agent.
- Work on a branch and open a PR. Never push to `main` or change rulesets.
- Roles: Chief of Chiefs routes tasks, Thunder-Terminal owns the VM, Cursor-Hammer implements,
  Watcher of Broken Things verifies, Keeper of Stone Tablets keeps briefs and handoffs.

## Safety
- Do not auto-approve MCP or shell, push, deploy, delete remote data, or message others.
- No secrets, personal data or absolute local paths in commits. Use relative paths.
- Commit as the alias `Ditto190 <Ditto190@users.noreply.github.com>`.
- Report: outcome, changed files, validation, blockers, next action. Do not paste raw logs.

## Review rubric
- **BLOCKER:** secrets, PII or absolute paths; broken `npm test`; unsafe or destructive commands.
- **NON-BLOCKER:** should be fixed in this PR if cheap, or tracked as a follow-up.
- **SUGGESTION:** optional style or design ideas; the author decides.

## Learned User Preferences
- Default agent **collection** is one investigator, one implementer, and one verifier; add agents only after this baseline passes pilot KPIs.
- Measure time from user request to a **validated brief** and from assignment to an **accepted patch** (verifier acceptance or merge criteria).
- Measure **context volume per handoff** between investigator, implementer, and verifier.
- Count **duplicate launches** for the same handoff or task key, **rework from stale inputs**, and **failed or missing receipts** on handoff steps.
- Measure **recovery after worker interruption** and how often **human intervention** is required to unblock a collection.
- Track **publication failures** separately from **implementation failures** in metrics and postmortems.
- Gate coordination with **deterministic tests** for invariants; use a research eval framework for answer quality only where it adds signal beyond those tests.
- Do not treat an **LLM grader** score or a **successful tool call** as proof of ownership, cancellation, or publication.
- First pilot must show an **interrupted task resumes** correctly along the same handoff chain without duplicate work.
- First pilot must show a **duplicate receipt is ignored** (idempotent promotion).
- First pilot must show **failed validation blocks promotion** even when implementation otherwise succeeded.

## Learned Workspace Facts
- Agent-collection KPI definitions, pilot gates, and handoff protocol direction are recorded in the project store ADR `docs/adr-agent-collection-kpis.md` (see store `preferences.md` index).
- Near-term implementation target is a **durable, versioned handoff protocol** built around this starter, not a separate orchestrator.
- **RDMA** stays deferred and belongs only behind the **model-serving boundary** if distributed GPU operations justify the complexity.
- Baseline collection topology (investigator → implementer → verifier) is the default Thunderstone pilot before parallel swarm expansion.
- Handoff evidence is expected as **versioned receipts** in the agent store; missing receipts count toward collection KPI failures.
- Coordination invariants belong in-repo as **deterministic tests**; answer-quality evals supplement research but do not replace promotion gates.
- Publication and implementation are distinct outcomes in KPI tables and automation (success at one does not imply the other).

<!-- lean-ctx -->
## lean-ctx

lean-ctx is active — the MCP tools replace native equivalents.
Full rules: LEAN-CTX.md (open on demand — do not auto-load).
<!-- /lean-ctx -->

## Close-out tracker

- Close-out status lives in `$THUNDERSTONE_OPERATIONAL_ROOT/state/CLOSEOUT-TRACKER.md` (system of record; the Grok Bot Page only mirrors it). Ids: P-xx project, C-xx codebase.
- Update only rows you own, plus that row's `updated` cell (ISO, AEDT `+11:00`). Append one line per changed field to `$THUNDERSTONE_OPERATIONAL_ROOT/state/closeout-tracker.log`: `ts | agent | id | field: old -> new`.
- No secrets. A row change is not approval: merge, push, close and delete still need DT's yes.
- Rules detail: `.cursor/rules/closeout-tracker.mdc`.
