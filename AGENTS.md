# Thunderstone Clan

Drive owns the starter and project intelligence. GitHub owns promoted active code.
Read this file, the assigned brief and current status only.

## Setup
- **Grok VM:** `sh scripts/bootstrap.sh`, `bash scripts/install-desktop.sh` (Xfce autostart), then `bash scripts/resume.sh` (Node 22+).
- **Cursor Cloud / CLI:** `sh scripts/bootstrap.sh` with optional `SKIP_CURSOR_INSTALL=1`, then `bash scripts/resume.sh`. Cloud builds use `scripts/cloud-bootstrap.sh` via `.cursor/environment.json`.
- Copy `.env.example` to `.env.local` only for secret-backed workflows (tasks, Drive export). `npm test` does not require it.
- Environment loading goes through `scripts/env-run.mjs`; credentials are injected at runtime.
- Domain registry and BDK orchestrator: `docs/domains.md`, `agents/clan-orchestrator/`.

## Commands
- `npm test` runs validation, ShellCheck and `scripts/check-hygiene.sh`.
- `bash scripts/doctor.sh` checks the local environment.
- `ALLOW_LOCAL_COMMITS=1 bash scripts/checkpoint.sh "<message>" <files>` makes a local checkpoint.
- Prefer deterministic CLI tools and APIs over browser clicking.

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

<!-- lean-ctx -->
## lean-ctx

lean-ctx is active — the MCP tools replace native equivalents.
Full rules: LEAN-CTX.md (open on demand — do not auto-load).
<!-- /lean-ctx -->
