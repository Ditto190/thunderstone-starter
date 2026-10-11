# Brief — Runner terminal smoke routine

To: Chief Thunderstone → create on Cursor-Runner (or Chief cron that briefs Runner)

Weekday 10:30 AEST (or next free slot): 
- Shell only: `cd $WORKSPACE/thunderstone-starter && bash scripts/resume.sh; echo $?`
- Write `$WORKSPACE/thunderstone/artifacts/runner-terminal-smoke-YYYYMMDD.md` (commands+exits)
- Visible terminal: only if DT asked for a demo that day; else headless Shell
- Silent to group if green; report to Chief one line if red
- CURSOR_AGENT=1: never exec agent/run-task.sh

Ack CoS when Runner cron/standing order exists.
