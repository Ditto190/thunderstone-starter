# Thunderstone tribes v2 (2026-10-10, proposal for DT; nothing applied by Runner)
Thin profiles, thick shared skills. Each bot keeps a job + hard rules (`<bot>.patch.md`, all <=1,600 chars) and loads skills from `$THUNDERSTONE_ROOT/skills/` (synced by `scripts/equip.sh` into `~/.grok/skills` and `~/.cursor/skills`):
- `house-rules`: 10 standing rules, tool order, chain of command, DT law
- `tool-howtos`: ts-* wrappers, gh, glab, ctx7, githits, Serena, LeanCTX, CodeRabbit CLI
- `brief-and-report`: Chief -> Runner brief format and the OUTPUT report
- `audit-area`: one-area audit brief (replaces Nightly Audit Engineer)
Hub-and-spoke still applies across tribes: 1:1 with the requester, no fan-out, no relaying via a third bot. Tribe work enters through the lead (or Grok Bot).

| Tribe | Lead | Members (id) | Rule |
|---|---|---|---|
| CONTROL | Grok Bot (0ef89b8b-d1c6-4c0c-a64d-e31c0dc4160c) | Grok Bot; dr eggbot (eaac08b1-1c4a-43b3-8b9c-57f97c9d818d) | Grok Bot routes every task to exactly one owner and talks to DT. dr eggbot creates bots only on DT's yes. |
| FORGE | Chief Thunderstone (45e99bd6-2e91-4e9d-a8a6-7737723bc377) | Chief Thunderstone; Cursor-Runner (a087ceb3-69d1-405a-bcbf-d862bcade158); Git-Scout (08fb189f-fd30-4451-a74f-92d4c3366551); tinkabot (75421954-c8f7-4609-8e30-0721c5fe576a) | Chief owns VM execution. Code/VM/CLI = Chief -> Runner (Cursor CLI). Git writes = Chief -> Git-Scout, DT approves the exact action. tinkabot packages the skills pack and plugin. |
| SWE / SDLC | Engineering Lead (d298c7a0-0f31-4ecc-afef-4643c1278320) | SWE (cfbb15f3-8d17-460d-aef4-18a71ddf2624); Senior Developer (1761543b-1e39-4b14-bb89-6e17924b72a5); Lingxi's Engineer Bot (81e154c6-b03a-4c31-82d1-1b767937d967); Projects Manager (7b71c6ec-6579-4f3f-92bc-64406b98f4dc) | Lead owns SDLC events; Chief owns VM execution. Event-triggered, no cadence, no CloudAgent launches; heavy work is a brief to Runner via Chief. |
| KNOWLEDGE and RESEARCH | none (each reports to the requester) | Chief Lorekeeper (e7b5b3b8-117e-43ff-a58d-e09fc7b7f35c); Researcher (38239e9c-d2be-4b6e-8e17-9acc5bcf26c3) | On demand via Grok Bot or Chief (Lorekeeper) and Grok Bot or Engineering Lead (Researcher). No routines. Drive is canonical for knowledge, GitHub for promoted code. |
| ADMIN | none | Executive Assistant (f9067a3d-1e7e-4985-a810-fa66d2ec2667); Tradbot (4b5e2379-a6c8-4da7-885a-ffe25646c52c) | Report to Grok Bot. EA: work calendar/email/Drive. Tradbot: personal lane only, no workers. Never send without DT's yes. |

## Retired or replaced (no v2 patch)
- Chief of Staff (437fcfe8-dea9-442e-99e8-739d914f6db7): retired; role absorbed by Grok Bot (routing, priorities, digest, DT escalation) and Chief Thunderstone (VM ops).
- Nightly Audit Engineer (08a36657-cc50-4461-945a-f4d7cb3de443): replaced by the `audit-area` skill / `briefs/TEMPLATE-AUDIT-AREA.md` (one area per run, as a Runner brief).

## Notes
- v2 patches shorten the v1 patches in `../*.patch.md`: job kept, rule block replaced by one skill pointer plus the hard rules (tool order, 1:1, silent when green, event-only routines, DT law line, health first turn). Bot-specific behaviour is unchanged.
- Profile length limit is unconfirmed; 1,600 chars remains the house target.
- Whether a Grok Bot can load these skills itself is NOT verified: see `$THUNDERSTONE_ROOT/artifacts/SHARED-SKILLS-TRIBES-2026-10-10.md` finding (b). Until verified the skill pointer carries a file-path fallback.
- Applying a patch to a bot profile is Grok Bot's job, with DT's yes.
