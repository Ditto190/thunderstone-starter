# Cursor Cloud ↔ Grok VM bridge

End-to-end setup so you talk to a **Cursor Cloud Agent** in the browser while **shell, git, and tests** run on the Grok Bot shared computer via a **My Machines** worker.

## Architecture

| Piece | Role |
| --- | --- |
| Cursor Cloud Agent (orchestrator chat) | Planning, tools, PR workflow |
| `agent worker` on the VM | Outbound registration to Cursor; executes tool calls on disk |
| `thunderstone` tmux session | Interactive shell on the VM |
| `thunderstone-worker` tmux session | Long-running worker (optional autostart) |
| Google Drive | Briefs and plans (MCP here; `rclone` on VM is separate) |
| GitHub | Promoted code and PRs |

Grok Bots on the same account still share the durable project folder and credentials. Use **git worktrees** for concurrent writers.

## One-time: VM foundation

1. Extract or clone the promoted repo into the Grok durable project directory.
2. `sh scripts/bootstrap.sh`
3. `bash scripts/install-desktop.sh` (desktop autostart)
4. Copy `.env.example` → `.env.local` and `config/cursor-worker.example.env` keys into `.env.local`.
5. `agent login` **or** set `CURSOR_API_KEY` in `.env.local` / `~/.config/thunderstone/env`.
6. In Cursor dashboard: **Cloud Agents → Self-hosted → allow My Machines**.

## Automated worker (this repo)

```bash
# Opt in: worker starts when resume runs
# In .env.local:
#   CURSOR_WORKER_AUTOSTART=1

bash scripts/resume.sh          # thunderstone shell + optional worker ensure
bash scripts/cursor-worker.sh start   # manual start
bash scripts/cursor-worker.sh status  # tmux + agent worker debug
bash scripts/doctor.sh                # includes worker status
```

Defaults (overridable in `.env.local`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `CURSOR_WORKER_NAME` | `grok-shared` | My Machines name / `worker=` routing |
| `CURSOR_WORKER_SESSION` | `thunderstone-worker` | tmux session for the worker |
| `CURSOR_WORKER_AUTOSTART` | `0` | `1` = `resume.sh` calls `ensure` |
| `CURSOR_WORKER_COMPUTER_USE` | `0` | `1` = pass `--computer-use` |
| `CURSOR_WORKER_DIR` | repo root | `--worker-dir` for the worker |

`agent login` alone does **not** register a worker; you must run `cursor-worker.sh start` or enable autostart.

## Connect the orchestrator chat

1. Start the worker on the VM (`status` shows `WORKER_SESSION=running`).
2. Open [cursor.com/agents](https://cursor.com/agents) → **New agent**.
3. Select repository `Ditto190/thunderstone-starter` (must match worker git remote).
4. Under **My Machines**, choose **`grok-shared`** (or your `CURSOR_WORKER_NAME`).
5. Attach MCPs you need (Google Drive, GitHub plugin, Context7 per project policy).

From Slack/GitHub/Linear you can route with `worker=grok-shared` when the repo matches.

## Verification checklist

| Step | Command / action | Pass |
| --- | --- | --- |
| VM tools | `bash scripts/doctor.sh` | Required tools OK |
| Worker process | `bash scripts/cursor-worker.sh status` | `WORKER_SESSION=running` |
| Cursor registration | `agent worker debug` on VM | Shows healthy registration |
| Cloud visibility | Cloud agent `list-self-hosted-workers` | Lists `grok-shared` |
| Smoke test | From orchestrator: create a file, `npm test` | Runs on VM checkout |

## Operating model

- **You → Cloud Agent (grok-shared)** for implementation you drive from chat.
- **Grok Bots** continue to use the same disk; coordinate with folders and branches.
- **Heavy one-shot jobs from Grok** can still use `node scripts/env-run.mjs bash scripts/run-task.sh <brief.md>` without nesting a Cloud Agent inside a Cloud Agent.
- **Drive**: orchestrator reads briefs via Google Drive MCP; export artifacts with `scripts/export-drive.sh` when `DRIVE_EXPORT_ROOT` is set on the VM.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| No machine in Cloud UI | Worker not running; re-run `start`; check outbound HTTPS to Cursor API |
| Wrong repo | `--worker-dir` must be a checkout whose `origin` matches the Cloud agent repo |
| Worker dies after reboot | Re-run `resume.sh` with `CURSOR_WORKER_AUTOSTART=1` or desktop autostart |
| `WORKER_DEBUG=unavailable` | `agent login` or `CURSOR_API_KEY` |

## Related Drive docs

Ingest the Grok Bot Ops Handoff Pack (`HANDOFF-INSTRUCTION.md`, `TOKEN-OPTIMIZATION.md`, `THUNDERSTONE-INTEGRATION.md`) for Chief routing and token policy. This bridge adds the **inverse** path: Cursor orchestrator → VM worker, not only Grok → `run-task.sh`.
