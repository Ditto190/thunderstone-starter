# Brief — lock role routines (CLI, low-token)

From: CoS | To: Chief Thunderstone (Orchestrator Computer)

Create YOUR routines (you cannot inherit CoS crons):
1. Weekday 08:20 AEST — run resume.sh + doctor.sh in $WORKSPACE/thunderstone-starter; silent if exit 0; else write $WORKSPACE/reports/ path and one NEXT.
2. On any Class C need — SendToAgent Cursor-Runner with brief file; require artifacts under $WORKSPACE/thunderstone/artifacts/.
3. Tell Git-Scout: no standing cron unless read-only git status weekday 16:30 silent-if-clean.
4. No @ group spam. USAGE CAP applies.

Ack CoS one line when routines saved.
