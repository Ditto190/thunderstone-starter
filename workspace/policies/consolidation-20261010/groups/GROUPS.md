# Thunderstone roster groups (2026-10-10, proposal for DT)
Hub-and-spoke. DT <-> Grok Bot (DT may DM any bot 1:1). Reports are a path + <=5 lines to the requester only. No fan-out, no group @s, no relaying via a third bot.

| Group | Bot (id) | Reports to / may message |
|---|---|---|
| CONTROL | Grok Bot (0ef89b8b-d1c6-4c0c-a64d-e31c0dc4160c) | DT; every group lead |
| BUILD (lead: Chief Thunderstone) | Chief Thunderstone (45e99bd6-2e91-4e9d-a8a6-7737723bc377) | Grok Bot; Runner, Scout, Engineering Lead (SWE Tribe), Lorekeeper |
| BUILD | Cursor-Runner (a087ceb3-69d1-405a-bcbf-d862bcade158) | Chief only |
| BUILD | Git-Scout (08fb189f-fd30-4451-a74f-92d4c3366551) | Chief only |
| BUILD (SWE Tribe) | Senior Developer (1761543b-1e39-4b14-bb89-6e17924b72a5) | Grok Bot or Engineering Lead; solution architecture; heavy work as a brief via Chief |
| BUILD (SWE Tribe) | Lingxi's Engineer Bot (81e154c6-b03a-4c31-82d1-1b767937d967) | SWE Tribe member; smart CI/CD and PR gates; event-triggered, no polling, no CloudAgent launches |
| BUILD | Nightly Audit Engineer (08a36657-cc50-4461-945a-f4d7cb3de443) | REPLACED by briefs/TEMPLATE-AUDIT-AREA.md (one area per run, as a Runner brief); bot retire = DT/Grok Bot to apply |
| BUILD (SWE Tribe) | SWE (cfbb15f3-8d17-460d-aef4-18a71ddf2624) | Engineering Lead or Chief; official Cursor SWE bot: code, triage, PR review, production issues; event-triggered |
| BUILD | tinkabot (75421954-c8f7-4609-8e30-0721c5fe576a) | Chief only; plugin-wrapping jobs, event-triggered |
| BUILD (SWE Tribe lead) | Engineering Lead (d298c7a0-0f31-4ecc-afef-4643c1278320) | Chief only; owns the engineering loop for the SWE Tribe; event-triggered, no cadence, no CloudAgent launches |
| KNOWLEDGE | Chief Lorekeeper (e7b5b3b8-117e-43ff-a58d-e09fc7b7f35c) | Grok Bot or Chief; on demand, no routines |
| KNOWLEDGE (SWE Tribe) | Researcher (38239e9c-d2be-4b6e-8e17-9acc5bcf26c3) | Grok Bot or Engineering Lead |
| ADMIN | Executive Assistant (f9067a3d-1e7e-4985-a810-fa66d2ec2667) | Grok Bot |
| ADMIN | Tradbot (4b5e2379-a6c8-4da7-885a-ffe25646c52c) | Grok Bot; no workers |
| PROJECTS (SWE Tribe) | Projects Manager (7b71c6ec-6579-4f3f-92bc-64406b98f4dc) | Grok Bot or Engineering Lead; codebase-side PM; board = GitHub Project #2 |
| PROJECTS | dr eggbot (eaac08b1-1c4a-43b3-8b9c-57f97c9d818d) | Grok Bot; creates bots only on DT's yes |
| HIDDEN | Chief of Staff (437fcfe8-dea9-442e-99e8-739d914f6db7) | retired; role absorbed by Grok Bot |

Not a bot: fdc323ab-1326-422e-9be3-c379b89ab7d4 "Thunderstone Clan" (group chat room, empty description; delete if unused, DT decides).
"New Bot" / "New Agent" placeholders: no profile.json found on disk under ~/agent-data/agents/, so no ids. Delete candidates (DT decides); ids needed from the UI.

## SWE Tribe (BUILD, under Chief Thunderstone)
Lead: Engineering Lead (d298c7a0-0f31-4ecc-afef-4643c1278320), owns the engineering loop. Reports to Chief Thunderstone only. Event-triggered; no cadence, no CloudAgent launches; heavy work is a brief to Cursor-Runner via Chief.
Members:
- SWE (cfbb15f3-8d17-460d-aef4-18a71ddf2624): official Cursor SWE bot; code, triage, PR review, production issues.
- Lingxi's Engineer Bot (81e154c6-b03a-4c31-82d1-1b767937d967): smart CI/CD and PR gates.
- Senior Developer (1761543b-1e39-4b14-bb89-6e17924b72a5): solution architecture.
- Projects Manager (7b71c6ec-6579-4f3f-92bc-64406b98f4dc): codebase-side PM on GitHub Project #2.
- Researcher (38239e9c-d2be-4b6e-8e17-9acc5bcf26c3): research for the tribe.
Tribe work enters through Engineering Lead (via Grok Bot or Chief); members report to the requester, 1:1 (path + <=5 lines). Hub-and-spoke still applies: no fan-out, no relaying via a third bot. Members keep their own group rows above.

## Rules
- DT reversed the earlier SWE / Engineering Lead retirement (2026-10-10): both are active. Nightly Audit Engineer stays replaced by briefs/TEMPLATE-AUDIT-AREA.md.
- Grok Bot routes every new task to exactly one owner. Code/VM/CLI = Chief -> Runner (Cursor CLI). Git writes = Chief -> Git-Scout, DT approves exact action.
- Lorekeeper, Researcher, EA, Tradbot, Projects Manager, dr eggbot never message each other; go through Grok Bot.
- Senior Developer: product code ownership; any multi-step CLI or repo analysis is a brief to Chief, not chat.
- Every bot carries the 10-rule block (STANDARD-PROFILE-BLOCK-SHORT.md, 894 chars).
- Profile length limit: unknown (no xAI docs result); 1.6k is the house target from dr eggbot's current standard.
- Per-bot new descriptions: `<name>.patch.md` in this folder (Grok Bot applies; nothing applied by Runner).
