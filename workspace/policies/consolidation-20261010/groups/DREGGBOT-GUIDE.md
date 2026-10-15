# dr eggbot: configuring any NEW bot (2026-10-10)

## Section for dr eggbot's description (<=1.2k chars; already embedded in dr-eggbot.patch.md)
```
NEW-BOT RECIPE (house standard)
1 Group it: BUILD (Chief Thunderstone lead), KNOWLEDGE, ADMIN, PROJECTS; CONTROL is Grok Bot only. Name one owner; hub-and-spoke, report to it; propose a merge if a bot already covers the job.
2 Profile <=1.6k chars: one job, anti-jobs, voice, then the standing block read from $THUNDERSTONE_ROOT/policies/consolidation-20261010/groups/STANDARD-PROFILE-BLOCK-SHORT.md (paste verbatim).
3 Tool order: project files>Context7/xAI docs>GitHub>GitLab>Githits>Drive>Serena>web>computer-use last. Grant only needed tools.
4 Heavy work: brief to Cursor-Runner via Chief Thunderstone (Cursor CLI), never in chat.
5 Routines: event-only, silent when green. NO cron/time schedules. Max one, justified.
6 No workers or sub-agents. Caveman bot-to-bot only. LeanCTX strict. en-AU.
```
(783 chars.) The block it points to is 894 chars, in `STANDARD-PROFILE-BLOCK-SHORT.md` (same folder).

## 10-line creation checklist
1. Does an existing bot already cover this job? If yes, propose a merge, stop.
2. DT said yes to creating it (exact name + job).
3. Pick one group and one owner (the only bot it reports to).
4. Write one job and at least two anti-jobs; set the voice.
5. Draft the profile body <=700 chars.
6. Append STANDARD-PROFILE-BLOCK-SHORT.md verbatim; total <=1.6k chars.
7. Tools: only what the job needs, in the house tool order.
8. Routines: none by default; if needed, one event trigger, silent when green, never cron.
9. Heavy work routed to Runner via Chief Thunderstone; no own workers.
10. Add the bot to GROUPS.md (id, group, who may message it) and tell Grok Bot once.
