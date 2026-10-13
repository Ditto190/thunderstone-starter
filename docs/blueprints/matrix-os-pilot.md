# Blueprint: Matrix OS as Thunderstone VM candidate

Status: PROPOSED (review required). Owner: Thunder-Terminal. Reviewer: Watcher of Broken Things.

## Role
Matrix OS (https://matrix-os.com/docs, source: github.com/HamedMP/matrix-os) is a candidate persistent agent workstation: one VPS per owner, persistent home, Zellij terminal sessions, CLI, port forwarding, and Claude Code / Codex / OpenCode / Pi support.
It is an execution plane only. GitHub stays the source of truth for code; Drive stays the source of project intelligence.

## Not solved by Matrix
- No first-class Grok/xAI agent: any Grok CLI or MCP adapter is our own integration.
- Sessions persist, but agents can still stop for approvals, restarts or plan limits.
- Multiple agents on one checkout will collide: use one worktree per writer.
- Agent logins (GitHub, providers) are set up separately inside the VM.

## Verify before relying on it
The first research pass could not read every docs page in full. Confirm these against live docs and `matrix doctor` during the pilot: CLI flags, plan sleep behaviour, MCP bridge config, backup/restore, port forwarding.

## Pilot (2 weeks, branch/PR access only)
See `config/blueprints/matrix-os.yaml` for the machine-readable checklist and guardrails.

## Exit criteria
Keep if: interrupted-run recovery works, intervention count is low, cost is acceptable, token revocation is tested. Drop otherwise and record the reason in `DECISIONS`-style notes in Drive.
