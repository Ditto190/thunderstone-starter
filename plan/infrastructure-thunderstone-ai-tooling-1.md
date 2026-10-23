---
goal: "Configure Thunderstone's local development stack and AI tooling"
version: "1.0"
date_created: "2026-10-23"
last_updated: "2026-10-23"
owner: "Thunderstone maintainers"
status: "Planned"
tags: [infrastructure, process, agent-tooling, developer-experience]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

This plan configures a portable Node 22 development path, project-scoped MCP
examples, and Copilot collaboration assets while preserving Thunderstone's
existing Linux VM workflow and receipt-gated investigator → implementer →
verifier collection. The existing
[local-dev brief](../workspace/briefs/dev-stack-local.md) is the acceptance
source for Dev Container and Context7/Caveman Cloud setup.

## 1. Requirements & Constraints

- **REQ-001**: Implement the acceptance criteria in
  `workspace/briefs/dev-stack-local.md`: a Node 22+ Dev Container, example MCP
  configuration, local-development runbook, Context7 environment variable
  name, and links from the specified project guides.
- **REQ-002**: Keep the Grok VM as the primary operating environment and the
  Dev Container/Codespaces path as a portable development option.
- **REQ-003**: Map AI-team orchestration roles onto existing Thunderstone
  briefs, handoffs, receipts, and pilot gates. Do not create a second source of
  truth such as a duplicate root `PROJECT_BRIEF.md` or sprint status tree.
- **REQ-004**: Preserve existing project instructions and MCP integrations;
  add only configuration that closes a demonstrated repository-specific gap.
- **REQ-005**: Copilot-generated assessment, SQL review, implementation, and
  agent-collaboration documents use the metadata and workflow routing rules in
  `.github/instructions/copilot-document-generation.instructions.md`.
- **REQ-006**: Document VM agent collaboration without conflating local agent
  profiles, Cursor Cloud My Machines execution, MCP mailbox completion, and
  the authoritative receipt-based promotion gate.
- **SEC-001**: Do not commit credentials, tokens, OAuth access data, personal
  data, or machine-specific absolute paths. Example environment files contain
  variable names and non-secret placeholders only.
- **SEC-002**: Do not enable automatic approval for shell/MCP actions, remote
  writes, pushes, merges, deployments, or browser actions. Preserve the human
  approval rules in `AGENTS.md` and `docs/browser-stack/ROUTING.md`.
- **SEC-003**: Keep user-specific Cursor configuration in ignored
  `.cursor/mcp.json`; do not copy credentials into tracked MCP examples.
- **CON-001**: Root scripts require Node.js 22 or newer. `workspace/bridge` is
  a separate Node package with an independent manifest and lockfile.
- **CON-002**: `config/browser/mcp.example.json` remains the separate browser
  stack example. The dev-stack MCP example contains only the servers required
  by the local-dev brief; do not duplicate browser, Origin, Composio, or
  Computer Use entries there.
- **CON-003**: The parent `projects/.vscode/settings.json` affects sibling
  workspaces. Do not change its permission or network settings as part of this
  plan.
- **GUD-001**: Use one investigator, one implementer, and one verifier as the
  default collection. Add optional roles only for a task that needs them and
  only after the deterministic pilot gates pass.
- **GUD-002**: Keep third-party Awesome Copilot assets distinct from
  repo-authored instructions. Record their source and revision; do not silently
  rewrite downloaded assets.
- **PAT-001**: Preserve existing names and status semantics in
  `docs/handoff-protocol.md` and `scripts/handoff-receipt.sh`.
- **PAT-002**: Use `.agents/mcp_config.json` for its existing agent-host
  configuration and `config/*/mcp.example.json` for portable examples copied
  into a client-specific, ignored configuration. Document one active
  configuration per MCP client to prevent duplicate servers.

## 2. Implementation Steps

### Implementation Phase 1

- **GOAL-001**: Restore a usable validation baseline without discarding
  in-progress repository changes.

| Task | Description | Completed | Date | Prerequisites |
|------|-------------|-----------|------|---------------|
| TASK-001 | In `scripts/validate.sh`, remove only the existing merge-conflict marker lines and retain every unique validation command currently present, including the run-task usage-limit, Thunderstone workspace, cloud-agent-root, and Cursor worker tests. Add `bash tests/infisical-run-test.sh` and extend the existing Node JSON parse check to cover `.agents/mcp_config.json` and `config/browser/mcp.example.json`; add the dev-stack and Dev Container JSON files when created. Do not revert or rewrite other modified files. | | | None |

**Exit criteria:** `scripts/validate.sh` contains no merge-conflict markers,
retains the existing test invocations, and passes `npm test`.

### Implementation Phase 2

- **GOAL-002**: Implement the accepted local-development brief without
  changing the VM-first runtime model.

| Task | Description | Completed | Date | Prerequisites |
|------|-------------|-----------|------|---------------|
| TASK-002 | Create `.devcontainer/Dockerfile` and `.devcontainer/devcontainer.json`. Use a Debian-based official Node 22 development image and pin its tested tag or digest; install `shellcheck` and `tmux`, run root `npm ci` after container creation, and set `SKIP_CURSOR_INSTALL=1` in the container environment so bootstrap/doctor checks do not install Cursor CLI. Keep the image suitable for `npm test` and `bash scripts/doctor.sh`; do not install Docker inside the container. | | | TASK-001 |
| TASK-003 | Create `config/dev-stack/mcp.example.json` with Context7 launched through `node scripts/env-run.mjs` and the `CONTEXT7_API_KEY` environment variable, plus the Caveman Cloud remote MCP OAuth URL template. Verify the endpoint format against Caveman Cloud's official connect documentation; do not invent an endpoint, authenticate, or store credential values. Include no Origin, Composio, Computer Use, or browser server entries. Keep `.agents/mcp_config.json` and `config/browser/mcp.example.json` as distinct client/configuration surfaces. | | | TASK-001 |
| TASK-004 | Create `docs/dev-stack/LOCAL-DEV.md` using `workspace/briefs/dev-stack-local.md` as the acceptance checklist. Document VM-primary operation, WSL probe notes, Dev Container/Codespaces startup, where the local MCP example is copied, how to prevent duplicate server activation, and the Grok My Machines operator checklist. Add only the name `CONTEXT7_API_KEY=` to `.env.example`, and link the runbook from `AGENTS.md` and `docs/grok-vm/cursor-cloud-bridge.md`. | | | TASK-003 |

**Exit criteria:** The brief's required files and links exist, all example
configuration is credential-free, and the documented Dev Container can run
root validation and `scripts/doctor.sh` with Cursor CLI installation skipped.

### Implementation Phase 3

- **GOAL-003**: Make Copilot collaboration follow Thunderstone's existing
  ownership, safety, and evidence protocol.

| Task | Description | Completed | Date | Prerequisites |
|------|-------------|-----------|------|---------------|
| TASK-005 | Update `.github/copilot-instructions.md` additively. Reference `docs/dev-stack/LOCAL-DEV.md`, `docs/handoff-protocol.md`, `docs/adr-agent-collection-kpis.md`, and the role-specific custom agents. State that the three-role collection remains the default, the producer never implements, agents do not recursively invoke agents, and promotion requires verifier acceptance plus passing validation. Do not duplicate setup prose already maintained in `README.md` or the runbook. | | | TASK-004 |
| TASK-006 | Create `.github/agents/thunderstone-producer.agent.md`, `.github/agents/collection-investigator.agent.md`, `.github/agents/collection-implementer.agent.md`, `.github/agents/collection-verifier.agent.md`, and `.github/agents/agent-collection-kpi-auditor.agent.md`. Adapt role behavior from `.cursor/agents/agent-collection-kpi-auditor.md` and the three `collection-*.md` files. Map Remy to planning/coordination only; require validated briefs and receipts; prohibit nested delegation, direct promotion by implementers, and claims unsupported by test/receipt evidence. Keep optional AI-team roles opt-in rather than increasing the baseline collection size. | | | TASK-001 |
| TASK-007 | Create `.github/instructions/shell.instructions.md` with `applyTo` limited to `scripts/**/*.sh`, `tests/**/*.sh`, `.cursor/hooks/**/*.sh`, and `workspace/scripts/**/*.sh`. Encode the POSIX-only `scripts/bootstrap.sh` exception, Bash strict-mode pattern for other scripts, ShellCheck coverage, and `scripts/env-run.mjs` for dotenv-aware commands. Create `.github/instructions/bridge.instructions.md` with `applyTo: "workspace/bridge/**/*"`; document the independent lockfile, Node ESM/TypeScript conventions, loopback-only HTTP service, authorization boundaries, and test port 3999 rather than production port 3847. Keep both files concise and do not repeat global instructions. | | | TASK-001 |
| TASK-008 | Run the Awesome Copilot suggestion workflows for skills, instructions, and agents against the current repository before adding any external assets. Record only resources that close an uncovered need. Current candidates are `agent-governance` and `agent-governance-reviewer`; do not add the generic `ai-ready` skill because it would duplicate the existing Copilot instruction setup. The preliminary catalog review has not identified a direct shell/Node/TypeScript instruction; repeat the full catalog review before deciding whether to add any. Install the two named candidates only after explicit user approval, using `.agents/skills/agent-governance/` and `.github/agents/agent-governance-reviewer.agent.md`; install the skill with `gh skills install github/awesome-copilot agent-governance` when `gh` is version 2.90.0 or newer, and record the upstream revision. Preserve downloaded contents unchanged. If approval is absent, leave both paths untouched and mark this task blocked. | | | TASK-001 |
| TASK-015 | Create `.github/instructions/copilot-document-generation.instructions.md` with scoped Markdown `applyTo` globs. Define front matter fields `document_type`, `copilot: true`, `tags`, `generated_by`, and repo-relative `source_files`. Route `/ai-team-orchestration`, `/github-copilot-modernization:assessment`, `/database-data-management:sql-code-review`, and `/structured-autonomy:structured-autonomy-generate` to their distinct uses and output paths. Limit tagging to explicitly requested skill-generated documents; preserve existing schemas and never add metadata to unrelated Markdown or third-party assets. | ✅ | 2026-10-23 | TASK-001 |

**Exit criteria:** Copilot has a repo-wide entry point, narrowly scoped
shell/bridge instructions, and role files whose responsibilities and
promotion rules agree with the existing Cursor agents and handoff protocol.
Third-party assets are either installed with approval and source revision or
remain uninstalled.

### Implementation Phase 4

- **GOAL-004**: Configure optional workstation tooling without widening
  repository or parent-workspace permissions.

| Task | Description | Completed | Date | Prerequisites |
|------|-------------|-----------|------|---------------|
| TASK-009 | Create `../thunderstone-starter.code-workspace` in the parent projects directory with one folder entry for `thunderstone-starter` and extension recommendations for GitHub Copilot, Copilot Chat, and Dev Containers. Do not add workspace settings that override shell/MCP permissions, local-network access, or parent `.vscode/settings.json`; keep this local workspace file outside the Git repository. | | | TASK-002 |
| TASK-010 | On the Windows host only, invoke the user-installed `/winui:winui-setup` workflow to install/verify Developer Mode, .NET SDK, WinApp CLI, and WinUI templates; verify with `dotnet --list-sdks`, `winapp --version`, and `dotnet new list winui`. Do not create a WinUI app, add `.csproj` files, or add WinUI dependencies to the Linux VM starter or CI. If the setup workflow is unavailable, mark this optional task blocked and do not install prerequisites manually. | | | None |
| TASK-011 | Configure the VM browser stack only from `config/browser/mcp.example.json` into ignored `.cursor/mcp.json`, following `docs/browser-stack/PLAN.md` and `docs/browser-stack/ROUTING.md`. Run `bash scripts/browser-doctor.sh` on the VM and verify CDP binds to loopback. Keep the browser stack separate from the dev-stack example and retain human approval for sensitive actions. | | | TASK-003 |
| TASK-016 | Create `docs/agent-collaboration-vm.md` with three clearly separated mechanisms: local agent profiles/hooks, Cursor Cloud My Machines execution, and the authenticated MCP mailbox. Document separate worktrees for concurrent writers; readiness commands for worker, registration, Cloud routing, mailbox health/connectivity, and smoke execution; protected per-agent tokens; and the fact that mailbox `done` does not satisfy `scripts/handoff-receipt.sh check-promotion`. Mark VM runtime and Cloud registration as unverified unless observed on the VM. Link the runbook from `.github/copilot-instructions.md`. | ✅ | 2026-10-23 | TASK-001 |

**Exit criteria:** The parent workspace file is isolated to Thunderstone; no
parent-wide permission changes occur; WinUI remains a Windows-host-only
optional capability; browser MCP remains separate and loopback-bound.

### Implementation Phase 5

- **GOAL-005**: Prove configuration consistency and close the handoff with
  deterministic validation evidence.

| Task | Description | Completed | Date | Prerequisites |
|------|-------------|-----------|------|---------------|
| TASK-012 | Add `tests/agent-config-invariants.sh` and invoke it from `scripts/validate.sh`. Verify required Copilot agent front matter and instruction `applyTo` scopes, including the document-generation metadata fields; JSON validity for `.agents/mcp_config.json`, both MCP examples, and `.devcontainer/devcontainer.json`; plus absence of credential values and forbidden server names in `config/dev-stack/mcp.example.json`. Check that collaboration docs distinguish mailbox status from promotion evidence. Use fixtures or names-only patterns; never print secret-like matched values. | | | TASK-002, TASK-003, TASK-005, TASK-006, TASK-007, TASK-015, TASK-016 |
| TASK-013 | From the repository root run `npm test`, `npm run lint`, and `npm run format:check`; run `bash tests/agent-collection-invariants.sh` and `bash tests/validate-brief-test.sh`. From `workspace/bridge`, run `npm ci`, `npm test`, and `npx tsc --noEmit`, using the bridge harness's non-production port 3999. Resolve only failures introduced by this plan; record environmental blockers without adding credentials. | | | TASK-012 |
| TASK-014 | After validation passes, record investigator, implementer, and verifier receipts with `bash scripts/handoff-receipt.sh record <receipt.json>` and verify `bash scripts/handoff-receipt.sh check-promotion <handoff_id>`. Promotion remains blocked unless the verifier receipt is accepted and `validation.passed` is true. | | | TASK-013 |

**Exit criteria:** All runnable root checks pass, bridge tests/type-check pass
or have an explicit environment blocker, config invariants pass, and promotion
eligibility is determined only by the verifier receipt.

## 3. Alternatives

- **ALT-001**: Copy the full AI Team Orchestration workflow, including its
  seven-role roster, root `PROJECT_BRIEF.md`, and sprint document tree. Rejected
  because it duplicates Thunderstone's current briefs/receipts and conflicts
  with its tested three-role baseline.
- **ALT-002**: Put project MCP settings and credentials in the parent
  `.vscode/settings.json`. Rejected because that file affects sibling projects
  and is not a safe home for credentials or Thunderstone-only behavior.
- **ALT-003**: Add WinUI project scaffolding or Windows App SDK dependencies
  to the repository. Rejected because the starter targets Linux VM operations
  and has no WinUI application project.
- **ALT-004**: Install every potentially useful Awesome Copilot skill, agent,
  or instruction. Rejected because it increases context and maintenance cost;
  add only approved assets with a direct project need.
- **ALT-005**: Add Playwright MCP beside the existing browser MCP stack.
  Rejected because the current browser stack already provides its documented
  routing path and a second active browser server would duplicate capabilities.

## 4. Dependencies

- **DEP-001**: Root Node.js 22+, npm lockfile, Bash, and ShellCheck as specified
  by `package.json`, `README.md`, and `.github/workflows/ci.yml`.
- **DEP-002**: `workspace/briefs/dev-stack-local.md` remains the accepted
  source of requirements for Dev Container and local MCP setup.
- **DEP-003**: A Dev Container-capable VS Code/Codespaces host and access to the
  official Node 22 development image and package repositories.
- **DEP-004**: Network access to `github/awesome-copilot` for current
  suggestions; explicit user approval is required before adding its assets.
- **DEP-005**: A Windows host and an installed `/winui:winui-setup` workflow
  for the optional WinUI workstation task.
- **DEP-006**: A configured Grok VM with the existing browser stack and the
  test credentials/port assumptions documented by `workspace/bridge`.
- **DEP-007**: GitHub CLI 2.90.0 or newer is required only if the approved
  `agent-governance` skill is installed with `gh skills install`.

## 5. Files

- **FILE-001**: `plan/infrastructure-thunderstone-ai-tooling-1.md` — this
  execution plan.
- **FILE-002**: `scripts/validate.sh` — retain existing tests, remove current
  conflict markers, parse new JSON examples, and invoke added invariant tests.
- **FILE-003**: `.devcontainer/Dockerfile` and
  `.devcontainer/devcontainer.json` — Node 22 development image and tools.
- **FILE-004**: `config/dev-stack/mcp.example.json` — Context7 and Caveman
  Cloud example with no credentials.
- **FILE-005**: `docs/dev-stack/LOCAL-DEV.md` — VM, WSL, Dev Container, MCP,
  and My Machines runbook.
- **FILE-006**: `.env.example`, `AGENTS.md`, and
  `docs/grok-vm/cursor-cloud-bridge.md` — env variable name and runbook links.
- **FILE-007**: `.github/copilot-instructions.md` — additive entry-point
  updates.
- **FILE-008**: `.github/agents/*.agent.md` — producer, collection roles,
  KPI auditor, and approval-gated governance reviewer.
- **FILE-009**: `.github/instructions/shell.instructions.md` and
  `.github/instructions/bridge.instructions.md` — path-specific conventions.
- **FILE-014**: `.github/instructions/copilot-document-generation.instructions.md`
  — workflow routing and metadata schema for requested Copilot-generated docs.
- **FILE-015**: `docs/agent-collaboration-vm.md` — VM collaboration mechanisms,
  readiness evidence, and promotion boundary.
- **FILE-010**: `.agents/skills/agent-governance/SKILL.md` — approval-gated
  upstream skill, if installed.
- **FILE-011**: `tests/agent-config-invariants.sh` — deterministic checks for
  agent/configuration shape and safety.
- **FILE-012**: `../thunderstone-starter.code-workspace` — optional,
  machine-local workspace wrapper outside the repository.
- **FILE-013**: Existing configuration surfaces to preserve:
  `.agents/mcp_config.json`, `config/browser/mcp.example.json`, ignored
  `.cursor/mcp.json`, `workspace/briefs/dev-stack-local.md`, and
  `docs/browser-stack/ROUTING.md`.

## 6. Testing

- **TEST-001**: `rg -n '^(<<<<<<<|=======|>>>>>>>)' scripts/validate.sh`
  returns no matches after TASK-001.
- **TEST-002**: `npm test` passes from repository root, including
  `tests/infisical-run-test.sh`, `tests/agent-config-invariants.sh`, and
  existing infrastructure and collection tests.
- **TEST-003**: `npm run lint` passes for scripts, hooks, and tests;
  `npm run format:check` reports no whitespace errors.
- **TEST-004**: `node -e 'for (const f of [".agents/mcp_config.json","config/browser/mcp.example.json","config/dev-stack/mcp.example.json",".devcontainer/devcontainer.json"]) JSON.parse(require("fs").readFileSync(f))'`
  succeeds after those files exist.
- **TEST-005**: `bash scripts/validate-brief.sh workspace/briefs/dev-stack-local.md`
  reports `brief_valid`.
- **TEST-006**: `bash tests/agent-collection-invariants.sh` confirms interrupted
  resume, duplicate-receipt idempotency, and validation-gated promotion.
- **TEST-007**: In `workspace/bridge`, `npm test` passes on port 3999 and
  `npx tsc --noEmit` succeeds; no test binds or probes production port 3847.
- **TEST-008**: On the target VM, `bash scripts/browser-doctor.sh` reports
  required tools/CDP ready and the browser CDP endpoint remains loopback-only.
- **TEST-009**: On the Windows host, the optional WinUI task reports installed
  SDK/CLI/template versions; it does not create project files in this repo.
- **TEST-010**: Inspect a skill-generated sample document to confirm its YAML
  metadata has a permitted `document_type`, boolean `copilot: true`, workflow
  and domain tags, exact `generated_by` skill command, and repo-relative
  `source_files`; confirm ordinary edited Markdown is not tagged automatically.
- **TEST-011**: Review `docs/agent-collaboration-vm.md` to confirm it identifies
  My Machines as execution rather than messaging, the mailbox as coordination
  rather than promotion evidence, and live VM checks as unverified until run
  on the VM.

## 7. Risks & Assumptions

- **RISK-001**: `scripts/validate.sh` currently contains unresolved merge
  conflict markers. Root validation is blocked until TASK-001 reconciles them.
- **RISK-002**: The working tree contains unrelated staged and unstaged edits,
  including Infisical changes. Execution must preserve them and must not
  overwrite, reset, or blanket-stage them.
- **RISK-003**: The parent `.vscode/settings.json` currently sets workspace-wide
  chat and local-network behavior. Changing it could affect sibling projects;
  this plan explicitly leaves it unchanged.
- **RISK-004**: Remote MCP OAuth details or Awesome Copilot assets may change.
  Validate the source at implementation time and do not store issued
  credentials or mutable tokens in tracked files.
- **RISK-005**: WinUI prerequisites apply only to Windows and have no role in
  Linux CI. The task is optional and must remain blocked if its setup workflow
  is not available.
- **ASSUMPTION-001**: `workspace/briefs/dev-stack-local.md` is the current
  approved local-development brief and should be implemented without changing
  its acceptance criteria.
- **ASSUMPTION-002**: AI Team Orchestration is available as a user-level skill;
  reuse it through repo-specific role mapping instead of copying its entire
  skill package into the repository.
- **ASSUMPTION-003**: The parent workspace wrapper is a personal convenience
  file and is intentionally not committed or shared with the repository.
- **ASSUMPTION-004**: No WinUI application is intended in this repository;
  the requested setup is for the Windows developer workstation only.

## 8. Related Specifications / Further Reading

- [Repository instructions](../.github/copilot-instructions.md)
- [Repository workflow and safety rules](../AGENTS.md)
- [Local-dev acceptance brief](../workspace/briefs/dev-stack-local.md)
- [Handoff protocol](../docs/handoff-protocol.md)
- [Agent collection KPI ADR](../docs/adr-agent-collection-kpis.md)
- [Cursor Cloud bridge runbook](../docs/grok-vm/cursor-cloud-bridge.md)
- [Browser stack plan](../docs/browser-stack/PLAN.md)
- [Browser routing policy](../docs/browser-stack/ROUTING.md)
- [Copilot document-generation instructions](../.github/instructions/copilot-document-generation.instructions.md)
- [VM agent-collaboration runbook](../docs/agent-collaboration-vm.md)
- [Awesome Copilot governance skill](https://github.com/github/awesome-copilot/tree/main/skills/agent-governance)
- [Awesome Copilot governance reviewer agent](https://github.com/github/awesome-copilot/blob/main/agents/agent-governance-reviewer.agent.md)
