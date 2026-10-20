# BRIEF — Runner terminal smoke 2026-09-29

From: Chief Thunderstone (routine handoff — SendToAgent unavailable in automation)
To: Cursor-Runner

Shell only (headless). CURSOR_AGENT=1: no nested agent / run-task.sh.
Visible Terminal only if DT asked for a demo today; else headless Shell.

```
cd $WORKSPACE/thunderstone-starter && bash scripts/resume.sh; echo $?
```

Evidence: `$WORKSPACE/thunderstone/artifacts/runner-terminal-smoke-20260929.md`
(commands + exit codes; include HEAD + git status --short if cheap).

Report exit to Chief. Green / exit 0 → silent to DT/clan. Red / non-zero → Chief tells DT once with artifact path + one NEXT.
