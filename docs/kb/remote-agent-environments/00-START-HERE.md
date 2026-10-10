# Thunderstone VM and Redis knowledge base

Edition: reconstructed from the preserved conversation, 11 October 2026. The earlier generated download files were not available in the execution workspace. This is a revised edition, not a byte-identical recovery. Status: preparation only; no VM pairing, installation or ingestion has been verified.

## Chapter 1. Ownership
GitHub owns this versioned KB. Proposed Drive mirror: 99_SYSTEM/AUTOMATION/Thunderstone/Knowledge Base/Remote Agent Environments/. That path is not a resolved folder ID or a created folder. Redis is a derived serving store, not a second independent source of truth. Ingest from one approved Git revision; do not double-ingest a Drive mirror.

## Chapter 2. Order
1. Verify the actual VM and checkout.
2. Pair Desktop Commander and validate remote access.
3. Register public documentation connectors.
4. Configure dedicated local Redis with protected credentials.
5. Configure local Redis data MCP.
6. Configure Chief roles and lifecycle collection.
7. Run acceptance tests.
8. Build KB chunks, then optionally add retrieval indexes after capability checks.

## Chapter 3. Agent-ready master task
```text
Act as Thunderstone environment maintainer. Read AGENTS.md and this KB. Inspect git status, existing MCP/hook settings, bootstrap/resume scripts and actual runtime before editing. The reported grok-bot-vm-347906125#/workspace label is a discovery reference, not a verified address or SDK agent ID.
Work on a feature branch. Merge settings; never overwrite existing configuration blindly. Complete reversible development work within scope and honour platform approval gates. Human completes OAuth, 2FA and connector registration.
Use pinned packages after checking their requirements. Do not install Docker unnecessarily. Do not expose Redis publicly, delete existing data, push to main, launch paid jobs or deploy without required authorisation.
Use native Cursor subagents initially. Give concurrent writers separate worktrees. Never recursively launch CLI agents from workers.
Return actual PASS/FAIL/BLOCKED/NOT RUN evidence, changed files, version pins, limitations, rollback and next action. Never print credentials or raw private transcripts.
```

## Chapter 4. Architecture
```text
Conversation -> Desktop Commander HTTPS/OAuth -> paired VM
VM -> Cursor Chief -> native subagents or separately supervised worktree workers
Validated lifecycle metadata -> Redis Streams and hashes
Permanent receipts -> files and approved GitHub promotion
Public documentation MCPs -> research, not VM control
```
Separate Cloud Agent VMs do not share this VM's localhost. Cross-VM Redis access requires a separately authenticated private network or service.
