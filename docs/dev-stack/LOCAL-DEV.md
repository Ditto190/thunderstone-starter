# Local-dev stack (VM primary + portable container)

Harden thunderstone-starter for day-to-day agent work. **Grok / My Machines VM** is the source of truth for shell, git, tests, worker registration, and Computer Use. Dev Container / Codespaces give a portable Linux validate/edit path. WSL2 on Windows laptops is optional and secondary.

## Layers

| Layer | What | Where |
| --- | --- | --- |
| L0 Bootstrap | `scripts/bootstrap.sh` → `doctor.sh` → `resume.sh` | Grok VM (primary); Dev Container `post-create` mirrors deps with `SKIP_CURSOR_INSTALL=1` |
| L1 Env | `.env.local` via `scripts/env-run.mjs` | Never commit; see `.env.example` |
| L2 MCP | `config/dev-stack/mcp.example.json` → `.cursor/mcp.json` | Context7 + Caveman Cloud only in this file |
| L3 Skills | `/caveman`, `/cursor-sdk`, `/agent-development`, `/orchestrate` | User/plugin skills (not vendored here) |
| L4 Collection | investigator → implementer → verifier | `.cursor/agents/collection-*.md` + handoff receipts |
| L5 Fan-out | My Machines worker `grok-shared` | `scripts/cursor-worker.sh` + Cloud Agent |

## Host comparison

| Host | Use | Notes |
| --- | --- | --- |
| **Grok / My Machines VM** | Primary | Designed for bootstrap, tmux, worker, optional Xfce / Computer Use |
| **Dev Container / Codespaces** | Portable validate/edit | Same Node 22 + CLI toolset; **not** a replacement for My Machines or desktop CUA |
| **WSL2 Ubuntu** | Optional IDE sidekick | Probe 2026-10-23: Ubuntu 26.04, 3 CPU / 6GB `.wslconfig`, repo on `/mnt/c/...`; missing native Node 22, jq, rg, fzf, shellcheck, rclone, agent; Docker Desktop WSL integration off; `guiApplications=false` |
| **Both (WSL + VM)** | Chat/edit on laptop; execute on VM | Cloud Agent → My Machines → `grok-shared` for heavy work |

## MCP: one server per service

Copy the example (gitignored target):

```sh
cp config/dev-stack/mcp.example.json .cursor/mcp.json
```

Then:

1. Set `CONTEXT7_API_KEY` in `.env.local` (loaded by `scripts/env-run.mjs` for the Context7 stdio server).
2. Replace `caveman-cloud.url` with the URL from Caveman Cloud console → **Connect your coding agent** (must end in `/mcp`). Authenticate via Cursor Tools & MCP (OAuth). Verify with `caveman_context`.
3. **Do not** add Composio, Cursor Origin, or Computer Use to this JSON.
4. Enable **Composio** via Marketplace plugin only.
5. Enable **Cursor Origin** and **Computer Use** in Cursor product settings. For worker CUA: `CURSOR_WORKER_COMPUTER_USE=1` in `.env.local` (see `config/cursor-worker.example.env`).
6. If the Context7 **plugin** is installed, disable it while project `context7` mcp.json is active (avoid duplicate namespaces).

Optional: merge browser stack keys from `config/browser/mcp.example.json` into the same `.cursor/mcp.json` carefully (one key per service).

### Cloud Agents

Attach Context7 (HTTP + `Context7-API-Key` header) and Caveman Cloud in the Cloud Agent MCP UI. Prefer the same services as local; never commit keys.

### Serena project configuration

The versioned `.serena/project.yml` selects the LSP backend and Bash and
TypeScript language servers for this starter. This is project configuration;
it does not install or expose the Serena MCP server on a laptop, VM, or Cloud
Agent host. Configure Serena in each host's approved agent settings separately.

After starting Serena from the repository root, read its initial instructions,
activate `thunderstone-starter`, and run onboarding when the project has not
been onboarded. A successful MCP tool call alone is not proof that language
servers started: verify the active backend is LSP and resolve a Bash symbol
and a TypeScript symbol before relying on Serena for code work.

## Dev Container / Codespaces

```sh
# VS Code / Cursor: Reopen in Container
# Or: GitHub Codespaces → create from this repo
```

- Image: `.devcontainer/Dockerfile` (Debian bookworm + Node 22 + bootstrap CLIs).
- `postCreateCommand`: `.devcontainer/post-create.sh` runs `npm ci` and `doctor.sh` with `SKIP_CURSOR_INSTALL=1`.
- Secrets: Codespaces / local secrets → env; never bake into the image.
- Worker + Computer Use: still start on the Grok VM (`docs/grok-vm/cursor-cloud-bridge.md`).

## Operator checklist (Grok VM)

1. Clone or update this repo on the durable VM disk.
2. `sh scripts/bootstrap.sh`
3. Copy `.env.example` → `.env.local`; merge keys from `config/cursor-worker.example.env`.
4. `agent login` **or** set `CURSOR_API_KEY`.
5. `bash scripts/resume.sh`
6. `bash scripts/cursor-worker.sh start` (or `CURSOR_WORKER_AUTOSTART=1`).
7. `cp config/dev-stack/mcp.example.json .cursor/mcp.json` and finish MCP steps above.
8. Cloud Agent → repo matching worker remote → **My Machines → grok-shared**.
9. Gate: `bash scripts/doctor.sh`, `bash scripts/cursor-worker.sh status`, `npm test`.

## WSL catch-up (deferred)

Only if you need local Linux `npm test` without the VM or Dev Container:

- Enable Docker Desktop → WSL integration for Ubuntu.
- Install native Node 22 + missing CLIs inside WSL (do not rely on Windows Node on PATH).
- Prefer a Linux-FS clone (`~/src/thunderstone-starter`) over `/mnt/c/...` for I/O.
- Leave `guiApplications` off unless you need local GUI; Computer Use stays on the VM.

## Collection

Baseline only until pilot KPIs pass (`docs/adr-agent-collection-kpis.md`):

1. Investigator brief under `workspace/briefs/`.
2. Implementer patch + `npm test` + receipt.
3. Verifier `accepted` + `bash scripts/handoff-receipt.sh check-promotion <handoff_id>`.

## Related

- `docs/grok-vm/cursor-cloud-bridge.md` — Cloud ↔ VM worker
- `config/browser/mcp.example.json` — browser MCP pattern
- `docs/handoff-protocol.md` — receipts
