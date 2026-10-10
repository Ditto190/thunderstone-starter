# Acceptance, recovery and handoff

## Chapter 1. Required checks
- Baseline: git status, actual branch, relevant hashes, versions, services and port ownership; no environment dump.
- Bridge: intended paired device, ping, repository read and terminal identity.
- Docs: tool discovery and a real source-backed lookup per connector.
- Redis: loopback binding, scoped write/read, other namespace denied, administration not granted.
- Persistence: restart retains a test record; disk recreation durability separately assessed.
- Data MCP: actual tools discovered and a scoped read/write verified with required authorisation.
- Streams: pending state, receipt before ACK, abandoned-work recovery.
- Hooks: correct task/run identities without sensitive payloads.
- Failure: killed test worker becomes interrupted, not successful.
- Redis outage: protected spool and deduplicated replay.
- Repository: existing tests and newly added behavioural checks; no credentials committed.
- KB: duplicate ingestion idempotent, fenced code preserved, fetchable IDs, active revision unchanged on failed staging.

## Chapter 2. Recovery and rollback
Never ACK lost work. Keep bounded retries and dead-letter evidence. Never trim entries needed by pending work. Export final receipts before expiring transient records.
Disable only new connector entries. Stop/revoke only new bridge pairing. Stop only dedicated Redis and preserve data/config. Revert feature-branch changes through review; never blanket-clean unrelated files or reset main.

## Chapter 3. Receipt
```text
Outcome: PASS / FAIL / BLOCKED / NOT RUN
Runtime identity:
Changed files:
Package versions and source commits:
Connectors configured / authenticated / functional:
Checks and evidence:
Persistence limitations:
Secrets handling:
Blockers:
Rollback:
Next action:
```
Writing configuration is not proving it works. No live checks were performed by merely saving this KB.
