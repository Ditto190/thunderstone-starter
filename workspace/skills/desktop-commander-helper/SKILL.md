---
name: desktop-commander-helper
description: >-
  Use when Desktop Commander device shows offline, the VM desktop is blank, or a
  DC/terminal session must be (re)launched and health-checked.
---

# desktop-commander-helper

Script: `$THUNDERSTONE_ROOT/scripts/dc-helper.sh`
Log: `$THUNDERSTONE_ROOT/artifacts/DC-REMOTE-2026-10-15.log`
One remote chain only — tmux session `dc`. No new bots.

## Steps
1. `bash $THUNDERSTONE_ROOT/scripts/dc-helper.sh status`
2. Exit codes: `0` green · `1` offline · `2` duplicate outside tmux `dc`
3. Offline → `restart` (kills only tmux `dc`, reports outside pids, never kills them)
4. Blank desktop shell → `term` (tmux `dc-term`; attach if TTY)
5. Receipt ≤5 lines, path-first → `$THUNDERSTONE_ROOT/artifacts/`

## Restart when offline
```
bash $THUNDERSTONE_ROOT/scripts/dc-helper.sh restart
bash $THUNDERSTONE_ROOT/scripts/dc-helper.sh status
```
Expect exit 0. If exit 2: duplicates exist — report pids, do not pkill outside `dc`.

## File changes
Route writes via Chief Thunder-Terminal → Cursor-Runner brief (`scripts/run-task.sh`).
Cross-ref: `cursor-cli-delegation` (workflows). Prefer extend that skill over new bots.

## Anti-patterns
- Second `desktop-commander remote` outside tmux `dc`
- `restart` then killing reported outside pids
- Secrets / tokens in chat or receipt
- Cron; event-only
