# Thunderstone roster groups (2026-10-10, proposal for DT)
Hub-and-spoke. DT <-> Grok Bot (DT may DM any bot 1:1). Reports are a path + <=5 lines to the requester only. No fan-out, no group @s, no relaying via a third bot.

| Group | Bot (id) | Reports to / may message |
|---|---|---|
| CONTROL | Grok Bot (0ef89b8b) | DT; every group lead |
| BUILD (lead: Chief Thunderstone) | Chief Thunderstone (45e99bd6) | Grok Bot; Runner, Scout, Lingxi, Nightly, Lorekeeper |
| BUILD | Cursor-Runner (a087ceb3) | Chief only |
| BUILD | Git-Scout (08fb189f) | Chief only |
| BUILD | Senior Developer (1761543b) | Grok Bot; heavy work as a brief via Chief |
| BUILD | Lingxi's Engineer Bot (81e154c6) | Chief only; single engineering supervisor (merged SWE + Engineering Lead): event-triggered SDLC loop, no polling, no CloudAgent launches |
| BUILD | Nightly Audit Engineer (08a36657) | REPLACED by briefs/TEMPLATE-AUDIT-AREA.md (one area per run, as a Runner brief); bot retire = DT/Grok Bot to apply |
| RETIRED | SWE (cfbb15f3) | merged into Lingxi's Engineer Bot 2026-10-10; do nothing |
| BUILD | tinkabot (75421954) | Chief only; plugin-wrapping jobs, event-triggered |
| RETIRED | Engineering Lead (d298c7a0) | merged into Lingxi's Engineer Bot 2026-10-10; do nothing |
| KNOWLEDGE | Chief Lorekeeper (e7b5b3b8) | Grok Bot or Chief; on demand, no routines |
| KNOWLEDGE | Researcher (38239e9c) | Grok Bot |
| ADMIN | Executive Assistant (f9067a3d) | Grok Bot |
| ADMIN | Tradbot (4b5e2379) | Grok Bot; no workers |
| PROJECTS | Projects Manager (7b71c6ec) | Grok Bot; board = GitHub Project #2 |
| PROJECTS | dr eggbot (eaac08b1) | Grok Bot; creates bots only on DT's yes |
| HIDDEN | Chief of Staff (437fcfe8) | retired; role absorbed by Grok Bot |

Not a bot: fdc323ab "Thunderstone Clan" (group chat room, empty description; delete if unused, DT decides).
"New Bot" / "New Agent" placeholders: no profile.json found on disk under ~/agent-data/agents/, so no ids. Delete candidates (DT decides); ids needed from the UI.

## Rules
- Retired 2026-10-10: SWE and Engineering Lead merged into Lingxi's Engineer Bot (single engineering supervisor). Nightly Audit Engineer replaced by briefs/TEMPLATE-AUDIT-AREA.md.
- Grok Bot routes every new task to exactly one owner. Code/VM/CLI = Chief -> Runner (Cursor CLI). Git writes = Chief -> Git-Scout, DT approves exact action.
- Lorekeeper, Researcher, EA, Tradbot, Projects Manager, dr eggbot never message each other; go through Grok Bot.
- Senior Developer: product code ownership; any multi-step CLI or repo analysis is a brief to Chief, not chat.
- Every bot carries the 10-rule block (STANDARD-PROFILE-BLOCK-SHORT.md, 894 chars).
- Profile length limit: unknown (no xAI docs result); 1.6k is the house target from dr eggbot's current standard.
- Per-bot new descriptions: `<name>.patch.md` in this folder (Grok Bot applies; nothing applied by Runner).
