# TOKEN-OPT-RULES (2026-10-15)
- Hub-and-spoke, 1:1: Chief -> one Runner per task. No fan-out to multiple bots.
- Briefs live in $THUNDERSTONE_ROOT/briefs/; messages carry the brief path only.
- Return = evidence path + <=5 lines. Evidence in artifacts/.
- No chat acks / "on it" messages; reply only with results or blockers.
- CLI-only to Runner; prefer `agent -p` (env -u CURSOR_AGENT, --trust, timeout) or scripts/run-task.sh.
- lean-ctx compression=max (global + repo .lean-ctx.toml).

## DC-first execution (2026-10-15, DT t122)
- Desktop Commander direct path confirmed: Grok chat runs `agent -p` and scripts via DC, no bot relay.
- Cursor-Runner and all VM bots: execute via DC `start_process` or `scripts/run-task.sh` / `agent -p` (CLI-only). Chat relay only for routing/approval.
- Skills: chief-router, caveman, bot-catalogue-bridge, lean-ctx.
- DC session: tmux `dc` (`npx -y @wonderwhy-er/desktop-commander@latest remote`); restart there if offline.
- Still: hub-and-spoke, brief files, path + <=5 lines, no fan-out, no commits without DT approval via Git-Scout.
