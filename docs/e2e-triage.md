# End-to-end triage

End to end means a brief goes in and a validated change plus a report come out. A human acts only at approval gates: push, pull request, deploy, and MCP or shell approval.

This starter is not an eve application. Tasks run in the existing Cursor agent or through one `agent` CLI launch. New product agents are out of scope until that path can finish a brief.

## Usage

```sh
node scripts/env-run.mjs node scripts/connect-mcp.mjs
```

A second run with the same environment prints `unchanged`. `config/mcp.example.json` is the only committed server list. `.cursor/mcp.json` is gitignored. Servers that are not in the example, such as a local `rustwright` entry, are kept. The managed `perplexity` server is replaced every run: empty `PERPLEXITY_API_KEY` writes the hosted URL for OAuth, and a set key writes `Authorization: Bearer` only in the gitignored file.

## Synthesis

The arena compared a shell renderer with three Perplexity modes against a Node catalog that also regenerates this document. The quality review rejected both a browser-folder entry and a second schema beside `mcp.json`. This file's map is the backlog. The example JSON is the connector list. `scripts/connect-mcp.mjs` is the only writer of the gitignored client config.

Perplexity Computer (`/rest/computer/mcp`) stays off this map. It is a separate escalation, not a second search server.

## Domain

Each gap has one state and one owner. States are `done`, `ready`, or `blocked`. Owners are the roles in `AGENTS.md`.

| ID | Gap | State | Owner | Next step |
|---|---|---|---|---|
| E1 | Bootstrap and resume | done | Thunder-Terminal | Keep `resume.sh` from starting a paid task |
| E2 | Perplexity MCP config | done | Thunder-Terminal | `node scripts/env-run.mjs node scripts/connect-mcp.mjs` |
| E3 | Live Perplexity tools | blocked | Watcher of Broken Things | After OAuth or a local key, confirm `perplexity_search`, `perplexity_ask`, `perplexity_research`, and `perplexity_reason` |
| E4 | Brief and status contract | blocked | Keeper of Stone Tablets | `AGENTS.md` names an assigned brief and current status. `workspace/` is empty and gitignored. Add `docs/brief.example.md` or delete the phrase |
| E5 | Headless task completion | blocked | Cursor-Hammer | `run-task.sh` `exec`s `agent -p` and never checks that `workspace/reports` received a file. Decide approval policy before adding `--force` |
| E6 | Verification after a task | ready | Watcher of Broken Things | When E5 drops `exec`, run `npm test` and record the result on the report |
| E7 | Cloud start path | done | Thunder-Terminal | `.cursor/environment.json` finds `scripts/` from the working directory, then `repos/thunderstone-starter` |
| E8 | Dashboard MCP for Cloud | blocked | Chief of Chiefs | Cloud agents do not load gitignored `.cursor/mcp.json`. Add one dashboard server named `perplexity` at the hosted URL |
| E9 | `config/clan.yaml` unread | ready | Keeper of Stone Tablets | Delete it or make `validate.sh` check the flags the scripts already hard-code |
| E10 | Two secret-pattern lists | ready | Cursor-Hammer | Stage router copies a subset of `scripts/check-hygiene.sh`. One rule file should feed both |
| E11 | Stage-router flag ladder | ready | Cursor-Hammer | Doc now matches the Project #2 result. The hook is still many booleans and serial `gh` calls |
| E12 | Role names | ready | Chief of Chiefs | `AGENTS.md` is the role list. README still says Grunts |
| E13 | `manifest.sha256` | ready | Keeper of Stone Tablets | The ZIP checksum list does not match git `main`. Generate it at release or stop telling git clones to run it |
| E14 | Checkpoint, PR, Drive export | done | Thunder-Terminal | Manual by policy. Do not automate push |

Delete a row in the pull request that closes it.
