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

## Catalogue

Do not copy agent trees into this repo. Load them from the Awesome Copilot MCP.
`bash scripts/awesome-copilot-mcp.sh` starts the official image when Docker is already installed.
Pointers: `.github/agents/`. Notes: `docs/mcp/CATALOGUE.md`.
Decision: `docs/adr/adr-0001-control-plane.md`. Evaluation: `docs/adr/adr-0002-archetype-fit.md`.

## Review rubric
- **BLOCKER:** secrets, PII or absolute paths; broken `npm test`; unsafe or destructive commands.
- **NON-BLOCKER:** should be fixed in this PR if cheap, or tracked as a follow-up.
- **SUGGESTION:** optional style or design ideas; the author decides.

<!-- lean-ctx -->
## lean-ctx

lean-ctx is active — the MCP tools replace native equivalents.
Full rules: LEAN-CTX.md (open on demand — do not auto-load).
<!-- /lean-ctx -->
