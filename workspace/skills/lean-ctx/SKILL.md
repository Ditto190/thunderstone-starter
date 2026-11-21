---
name: lean-ctx
description: >-
  Use on the shared box for any shell command or file read whose output may be
  long. Compress it before it enters context; recover exact source only when needed.
---

# lean-ctx (official, v3.12.6)

Source: https://github.com/yvgude/lean-ctx
Box binary: `lean-ctx --version` (expect 3.12.6). Health: `lean-ctx doctor`.
Config: `compression_level=max`, `tool_profile=standard` (RULES "lean-ctx max"
means compression policy, not the power tool tier).

## When to use
- Build, test, git or log output that may be long.
- Need a file's shape before its body.
- Not for: short known files, or exact bytes (use `raw`).

## Grok Bot / shared computer paths
| Client | How to call lean-ctx |
|--------|----------------------|
| Cursor IDE / Cursor-Runner | MCP `ctx_*` (shadow mode routes native read/search/shell) |
| Grok CLI | MCP server `lean-ctx` (`lean-ctx mcp`) |
| Other bots (no MCP) | `ts-lean-ctx map\|signatures\|read\|grep\|run` |
| Interactive shell | `lean-ctx -c "..."` / bash shell-hook |

## Steps
1. Verify: `lean-ctx --version`; `lean-ctx doctor`; `lean-ctx tools health`.
2. Orient: `ctx_compose(task)` or `ts-lean-ctx map <file>` first — not whole-file dumps.
3. Shell: `lean-ctx -c "<cmd>"` or `ts-lean-ctx run "<cmd>"`.
4. Exact output: `lean-ctx raw "<cmd>"` (escape hatch only).
5. File outline: `lean-ctx read <file> -m map` or `-m signatures`.
6. Line range: `lean-ctx read <file> -m lines:N-M`. After an edit: `-m diff`.
7. Search: `lean-ctx grep <pattern> [path]` (not `lean-ctx -c rg ...`).
8. Truncated output: tee under `~/.local/state/lean-ctx/tee/` — expand, do not re-run.
9. Density: this box stays on `max` (`lean-ctx compression` / config.toml).
10. Maintenance: `lean-ctx cache prune`; `lean-ctx tools standard`.

## Anti-patterns
- Using `-c` to `cat`, `sed`, `grep` or `rg` a file. Use `read` or `grep`.
- Re-running a command for more output. Expand the tee / `ctx_expand` instead.
- Sleep-polling a job.
- Quoting compressed output as exact evidence. Use `raw`.
- `LEAN_CTX_DISABLED=1` as a default (equip may set it for its own process only).
- Switching to `tools power` for "more savings" — more schemas raise fixed cost.
- Path-list dumps (`find`/`ls -R`) via `-c` alone — prefer `ctx_tree` / map.

## MCP (when ctx_* tools are loaded)
- Orient with `ctx_compose(task)` first; read with `ctx_read(path, mode=signatures|map)`.
- Recover compressed output with `ctx_expand(id)`.
- Exclusive (no native shadow): compose, symbol/semantic search, callgraph, knowledge, session.
