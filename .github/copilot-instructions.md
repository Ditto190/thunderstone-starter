# Thunderstone starter

Drive-first control plane for a Grok Bot computer and Cursor Cloud Agents.
Not an application. Do not add a database, cache, or product framework here.

## Stack

- Shell scripts under `scripts/`, Node 22 for `scripts/env-run.mjs` only.
- Package manager: npm. The only dependency is husky.
- Validation: `npm test` (syntax, ShellCheck, hygiene, env precedence).

## Laws

- Read `AGENTS.md` and `docs/adr/adr-0001-control-plane.md`.
- One owner per task. One git worktree per writer. Never push to `main`.
- Do not recursively launch another agent.
- No secrets, personal data, or absolute local paths in commits.
- Prefer CLI and MCP over browser clicks.

## Catalogue

Do not copy agents from `modme-ui-01` or `awesome-copilot` into this repo.
Start `bash scripts/awesome-copilot-mcp.sh` and use `load_instruction`.
The five files in `.github/agents/` are pointers, not the upstream bodies.

## Do not

- Vendor the 60-file or 200-file agent trees.
- Install Docker from bootstrap. The catalogue script refuses if Docker is missing.
- Register a loopback MCP URL on grok.com.
