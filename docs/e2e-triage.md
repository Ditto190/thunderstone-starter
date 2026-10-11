# End-to-end lanes

`config/e2e.json` is the contract. `node scripts/triage.mjs` derives each lane. Nothing in that file stores a status.

| Lane | Derived when the contract holds | Still operator-owned |
|---|---|---|
| boot | `scripts/doctor.sh` is in the repo | Live VM install, login, reboot |
| task | `scripts/run-task.sh` is in the repo | Cursor `agent` on PATH, inside Cloud execute directly |
| brief | — | A brief under `workspace/briefs` |
| drive-export | `DRIVE_EXPORT_ROOT` is named in `.env.example` | rclone remote and the export root value |
| perplexity | `PERPLEXITY_API_KEY` is named in `.env.example` | The key, then `node scripts/triage.mjs mcp > .cursor/mcp.json` |
| browser | — | Docker, CloakBrowser, agent-browser, Scrapling |

Connectors in the same file are the only MCP list. Perplexity is `https://api.perplexity.ai/mcp` with a bearer header taken from the environment. xAI docs is `https://docs.x.ai/api/mcp` with no key. Perplexity Computer is an OAuth escalation, not the default. GitHub and Drive stay native connectors. This repo does not add an eve app, a database, or a second orchestrator. New product agents belong in their own eve project.

## Synthesis

Two sketches were compared. One stored the control plane in a JSON document and kept hygiene in a shared shell rule file. The other derived lane state from a closed union inside one Node module and moved secret scanning into that module.

The shipped shape keeps derived state and the shell rule file. Secret scanning stays in shell because the CI gate and the session hook already speak shell, and a Node hop on the hook adds a process without deleting a rule. Lane status stays derived because a stored status string can disagree with the files. `config/clan.yaml` stays. It is unread policy, and replacing it would create a second constitution next to AGENTS.md.

Agents still to build, outside this starter: a product eve app is not this repo. The open operator work is the brief, the Drive remote, the Perplexity key, and a VM browser smoke test.
