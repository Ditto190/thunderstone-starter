# Chief, hooks and Redis orchestration

## Chapter 1. Native patterns
Sources: https://cursor.com/docs/sdk/typescript, https://cursor.com/docs/subagents, https://cursor.com/docs/hooks, https://github.com/cursor/cookbook
Inspect the official SDK/DAG task-runner examples before building a new framework. Use one Chief, bounded Implementer and independent Verifier. Native subagents do not justify assuming separate checkouts. Concurrent writers need explicit worktrees. No recursive CLI spawning.

## Chapter 2. Chief prompt
```text
Own a scoped task from product brief to evidence-backed handoff. Read AGENTS.md and actual current state. Name acceptance criteria before implementation. Investigate observable facts yourself. Delegate through supported native subagents. Review actual diff/tests, not only worker summaries. Write selected task/run metadata under ts:dev:* and permanent receipts to files. Keep environment changes under one maintainer. Honour approval and budget gates. Do not store hidden reasoning, credentials, unrestricted tool payloads or raw private transcripts. Preserve resumable state on stop.
```

## Chapter 3. Event shape and keys
```json
{"schemaVersion":1,"eventId":"uuid","projectId":"thunderstone","runId":"run-id","taskId":"task-id","agentId":"agent-id","kind":"run.started","timestamp":"ISO-8601","payload":{"role":"chief"}}
```
```text
ts:dev:task:<id> hash
ts:dev:run:<id> hash
ts:dev:events stream
ts:dev:jobs stream
ts:dev:worker:<id> expiring heartbeat
ts:dev:dead-letter stream
```
Validate event metadata and size at the boundary. Deduplicate event IDs. Do not claim exactly-once side effects from Streams.

## Chapter 4. Streams demonstration
Load credentials privately first. Only use dedicated test keys:
```bash
redis-cli -p 6380 --user thunderstone XGROUP CREATE ts:dev:jobs-test workers 0 MKSTREAM
redis-cli -p 6380 --user thunderstone XADD ts:dev:jobs-test '*' taskId TEST-001 kind smoke
redis-cli -p 6380 --user thunderstone XREADGROUP GROUP workers worker-1 COUNT 1 STREAMS ts:dev:jobs-test '>'
redis-cli -p 6380 --user thunderstone XPENDING ts:dev:jobs-test workers
redis-cli -p 6380 --user thunderstone XACK ts:dev:jobs-test workers RETURNED_ENTRY_ID
redis-cli -p 6380 --user thunderstone XAUTOCLAIM ts:dev:jobs-test workers worker-2 60000 0-0 COUNT 1
```
Treat BUSYGROUP separately from other failures. ACK only after work and receipt are persisted. Use Pub/Sub only for disposable refresh notifications.

## Chapter 5. Hooks and supervisor
Fetch exact installed-version hook schemas before editing configuration. Proposed mappings: session start -> run.started; subagent start/stop -> lifecycle records; pre-compaction -> handoff; session end -> terminal outcome only if known. Hook stdout must satisfy Cursor's protocol; diagnostics cannot pollute JSON-only output.
A killed process may never emit an end hook. Supervisor monitors exit, heartbeat expiry and reconciliation. Protected local spool preserves failed writes. Replay with deduplication.

## Chapter 6. SDK event collector requirements
Select @cursor/sdk and redis client versions, preserve package/lockfiles, compile first. SDK local runtime still uses service/model access and can incur usage. Do not launch paid work for a syntax test.
Keep normalised agent/run IDs and permitted lifecycle metadata; exclude thinking and unrestricted tool argument/result shapes. Add timeouts, backpressure, durable spool, schema validation and terminal-state recovery. Request read-only mode through supported enforcement, not only prompt text. No SDK code is claimed compiled or tested in this edition.
