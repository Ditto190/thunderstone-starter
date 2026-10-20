# Work item

## Problem

The starter had a brief, a Cursor CLI launch, a report directory, and a Drive export, and nothing that joined them. `config/clan.yaml` named the contract and no script read it. Perplexity was specified in the Drive knowledge base and absent from the repo.

## Usage

```sh
node scripts/clan.mjs new TASK-001 --role cursor-hammer
bash scripts/run-task.sh TASK-001
node scripts/clan.mjs status TASK-001
bash scripts/export-drive.sh TASK-001
```

`run-task.sh` and `export-drive.sh` load the environment, then call `scripts/clan.mjs`. Print mode stays without `--force`. The wrapper writes `workspace/items/<ID>/report.md` from the agent's final message.

## Shape

`workspace/items/<ID>/` is the work item. `brief.md`, `runs.jsonl`, `report.md`, `export/`, and `receipts.jsonl` each have one writer. `loadItem` derives `briefed`, `running`, `interrupted`, `failed`, `reported`, `curated`, or `exported`. An export without a report is invalid.

`scripts/clan-contract.mjs` owns the roster, the hosted connector `https://api.perplexity.ai/mcp`, env names, and labels. `node scripts/clan.mjs sync` renders `config/clan.yaml`, `.env.example`, `.env.defaults`, `.github/labeler.yml`, `config/mcp.example.json`, and the roles block in `AGENTS.md`. `npm test` fails when those views drift. The MCP example uses `Bearer ${env:PERPLEXITY_API_KEY}` and never a key value.

Instruction-only roles cannot own a brief. Routine roles get `perplexity_search`. `chief-investigator` also gets `perplexity_research`. There is no SDK dependency.

## Synthesis decision

Base: the item-as-directory candidate. State stays in the files, the runtime stays zero-dependency ESM, and the shell entry points stay `run-task.sh` and `export-drive.sh`.

Taken from the other candidate: one phase answer for a brief, and no live key written into an MCP file.

Rejected: a TypeScript module in a repo whose only dependency is Husky, a caller that substitutes `PERPLEXITY_API_KEY` into `.state/mcp-*.json`, and telling print mode to save its own report. Cursor's headless docs say `-p` without `--force` only proposes edits.

## Tradeoffs

- We accept a reported item staying put until a human deletes `report.md`, in exchange for not paying for a second run.
- We accept deterministic Drive folders `<ID>/<digest12>`, in exchange for a crash between upload and receipt retrying the same folder.
- We accept contract edits in `scripts/clan-contract.mjs`, in exchange for not adding a YAML parser.
- We accept a deny-only `.cursor/cli.json` for the life of a spawned run, removed when the process returns. A file left behind only narrows tools.

## Deferred

Browser smoke, Rustwright, computer-use escalation, domain playbooks, a Project board client, lean-ctx, and a rewrite of the stage router stay out of this change. Monitor label names now come from the contract. The four secret scanners are still separate. `manifest.sha256` remains the Drive release checksum.
