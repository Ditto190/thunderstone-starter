# Brief — Runner terminal smoke 2026-09-24

From: Chief Thunderstone (routine 289420cb)
To: Cursor-Runner (CLI Executor)
Note: 1:1 SendToAgent unavailable in automation subagent; Chief executes equivalent headless Shell on shared VM.

## Task
Shell only (CURSOR_AGENT=1 — no nested agent/run-task.sh):
```
cd $WORKSPACE/thunderstone-starter && bash scripts/resume.sh; echo $?
```
Write evidence: `$WORKSPACE/thunderstone/artifacts/runner-terminal-smoke-20260924.md` (commands + exit codes).
Visible Terminal: no (DT did not ask for a demo today).

## Report
Green/exit 0 → silent. Red → one NEXT to Chief.
