---
name: lean-ctx
description: >-
  Use on the shared box for any shell command or file read whose output may be
  long. Compress it before it enters context; recover exact source only when needed.
---

# lean-ctx (official, v3.10.2)

Source: https://github.com/yvgude/lean-ctx @ b14bf2f995119615e14190c50aee079fd6967f1c
Skill: `skills/lean-ctx/SKILL.md` @ 801775cd. Cites below: README.md, docs/reference/02-daily-use.md, SKILL.md.

## When to use
- Build, test, git or log output that may be long.
- Need a file's shape before its body.
- Not for: short known files, or exact bytes (use `raw`).

## Steps
1. Verify: `lean-ctx --version` (expect 3.10.2). Health: `lean-ctx doctor`.
2. Shell: `lean-ctx -c "<cmd>"` (README, Everyday commands).
3. Exact output: `lean-ctx raw "<cmd>"` (README, Everyday commands).
4. File outline: `lean-ctx read <file> -m map` or `-m signatures` (README; 02-daily-use).
5. Line range: `lean-ctx read <file> -m lines:N-M`. After an edit: `-m diff`.
6. Search: `lean-ctx grep <pattern> [path]` (SKILL, Without MCP).
7. Truncated output: full text is teed to `~/.local/state/lean-ctx/tee/`
   (shared 24h TTL, `rust/src/proxy/ccr.rs`). Open that file if the summary is not enough.
8. Long commands (SKILL, Long-running commands): start, do other work, check once
   when the result is needed.
9. Density: `lean-ctx compression off|lite|standard|max` (CLI help; local preference).

## Anti-patterns
- Using `-c` to `cat`, `sed`, `grep` or `rg` a file. Use `read` or `grep`
  (SKILL, Intent to tool: bypasses read cache and symbol index).
- Re-running a command for more output. Expand the tee file instead (SKILL, Truncated output).
- Sleep-polling a job (SKILL, Never wait by polling).
- Quoting compressed output as exact evidence. Use `raw`.
- `LEAN_CTX_DISABLED=1` as a default. It bypasses all compression (CLI help, SAFETY).
- Inventing an audit-log switch. Upstream documents none; `doctor` is the health check.

## MCP (when ctx_* tools are loaded)
- Orient with `ctx_compose(task)` first; read with `ctx_read(path, mode=signatures|map)`.
- Recover compressed output with `ctx_expand(id)` (README, Source recovery; SKILL).
- Recovery depends on retention and source availability (README, Source recovery).
