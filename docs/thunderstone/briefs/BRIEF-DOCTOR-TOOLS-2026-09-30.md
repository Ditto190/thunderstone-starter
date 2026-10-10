# BRIEF — Restore doctor tools (2026-09-30)

From: Chief Thunderstone
To: Cursor-Runner (Class B / Class C tooling)
Trigger: VM morning resume+doctor YELLOW — doctor exit 1

## Goal
Install missing doctor tools on Agent Computer, then confirm `doctor.sh` exit 0.

## Missing
zip, fzf, rclone, shellcheck, make

## Steps (Shell, headless; CURSOR_AGENT=1 — no nested agent/run-task.sh)
1. Detect package manager; prefer apt if available.
2. Install the five packages (non-interactive). If sudo needed and blocked, stop and report exact blocker.
3. Verify: `command -v` for each of zip fzf rclone shellcheck make
4. `cd $WORKSPACE/thunderstone-starter && bash scripts/doctor.sh; echo $?`
5. Evidence: `$WORKSPACE/thunderstone/artifacts/DOCTOR-TOOLS-RESTORE-2026-09-30.md` (commands, exits, doctor output summary)
6. No git write. Report exit to Chief.

## Success
doctor.sh exit 0; all five on PATH.
