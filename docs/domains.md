# Domain registry

Thunderstone encodes review and orchestration domains in
`config/domains/registry.json` instead of scattering lane names across
scripts.

## Concepts

| Field | Meaning |
| --- | --- |
| `stages` | Advisory stage-router phases: `monitor`, `triage`, `build` |
| `lanes` | Review workflows: `review_and_ship`, `pr_review_canvas`, etc. |
| `entries` | Domain ids with maintainer subagents and stage hints |
| `transitions` | Allowed next stages from each current stage |

The BDK agent `agents/clan-orchestrator` loads this file through the
`resolve_domain` tool (`bot/lib/domain-model.ts`).

## Cursor subagents

| Subagent | Maintains |
| --- | --- |
| `domain-registry-maintainer` | Registry JSON + domain-model types |
| `pr-review-canvas` | HTML review artifacts |
| `docs-reliability-review` | Documented setup paths (built-in) |
| `Comment Sicko` | Instruction and comment debt (built-in) |

## Running tasks

- Cursor CLI brief: `node scripts/env-run.mjs bash scripts/run-task.sh workspace/briefs/TASK.md`
- BDK brief: `node scripts/env-run.mjs bash scripts/run-bdk-task.sh workspace/briefs/TASK.md pr_orchestration`

## Backend hosting

`clan-orchestrator` is a [BDK](https://www.npmjs.com/package/@cursor/bdk) agent:
HTTP playground, tools, and GitHub webhooks via `bdk serve` / deploy to Vercel
Functions (Fluid compute). See `agents/clan-orchestrator/bot/channels/github.ts`.
