# Agent runtime

Local control plane for bounded agent work. Complements the read-only `sessionStart` stage router; it does not replace it.

## Lifecycle

`queued` → `leased` → `submitted` → `validated` → `accepted`

Terminal outcomes: `failed`, `blocked`.

## Commands

```sh
node scripts/agent-runtime.mjs init --task examples/agent-runtime/task.json
node scripts/agent-runtime.mjs lease --task-id TS-DEMO-001 --worker cursor-hammer
node scripts/agent-runtime.mjs prompt --task-id TS-DEMO-001
node scripts/agent-runtime.mjs submit --receipt path/to/receipt.json
node scripts/agent-runtime.mjs validate --task-id TS-DEMO-001
node scripts/agent-runtime.mjs accept --task-id TS-DEMO-001
```

`scripts/run-runtime-task.sh` leases a task and prints the compiled worker prompt. It does not launch Cursor CLI or start paid agent work.

## State

Task state lives under `.state/agent-runtime/` (gitignored). Receipts are idempotent by `receiptId`. Leases expire per `config/agent-runtime.json`.

## Gates and acceptance

- **Gates** run after submit (`validate`). Failed gates move the task to `blocked`.
- `command` runs a fixed argv with a timeout.
- `pr-review` reads GitHub check rollup (`gh pr view --json statusCheckRollup`) and fails closed unless every required check conclusion is `success`. It does not merge, push, or comment. Tests pass a repo-relative `fixture` instead of calling GitHub.
- `conflict-scan` rejects conflict markers in listed paths. When `base` is set it also runs read-only `git merge-tree` against that ref and fails closed on conflicts or a missing ref.
- **Acceptance** runs on `accept` with a configured timeout. Outputs named `package-lock.json`, and any `conflictScan.paths`, are scanned for conflict markers before accept.

## Safety

No automatic push, merge, deploy, or external messaging. Workers must match the task pool; stale `attemptId` values are rejected on submit.
