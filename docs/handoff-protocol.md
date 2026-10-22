# Handoff protocol (v1)

Versioned receipts for investigator → implementer → verifier collections.

## Receipt file

Path: `workspace/handoffs/<handoff_id>/receipt-<role>-<receipt_id>.json` (gitignored `workspace/`).

## Schema (v1)

```json
{
  "protocol_version": 1,
  "handoff_id": "tsk-20261011-001",
  "receipt_id": "rcpt-uuid",
  "role": "investigator",
  "status": "validated",
  "created_at_ms": 0,
  "parent_receipt_id": null,
  "brief_path": "workspace/briefs/TASK-001.md",
  "context_bytes": 0,
  "validation": { "passed": true, "runner": "scripts/validate-brief.sh" }
}
```

Roles: `investigator` | `implementer` | `verifier`.

Statuses:

- Investigator: `validated` (brief ready)
- Implementer: `patch_ready` | `blocked`
- Verifier: `accepted` | `rejected` | `promotion_blocked`

## Idempotency

Same `receipt_id` written twice must be **ignored** (hooks + `scripts/handoff-receipt.sh record`).

## Promotion

Promotion (merge, publish, deploy) requires verifier `accepted` and `validation.passed === true`. Implementation-only success does not promote.

## Metrics

Cursor hooks append to `.cursor/hooks/state/collection-metrics.jsonl` (see `.cursor/hooks/collection-metrics.sh`).
