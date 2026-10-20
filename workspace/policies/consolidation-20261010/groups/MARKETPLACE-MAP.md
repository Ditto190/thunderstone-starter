# MARKETPLACE-MAP (2026-10-10, read-only survey; nothing edited or created)

Source of membership: `~/agent-data/settings.json` -> `sidebarSections[1]` (id `section-mv26drbn-1`, name "Marketplace"). Real data, not a guess. 8 bots.

## Table

| # | Name | Id | One-line job (from profile) | Section | Roster overlap |
|---|---|---|---|---|---|
| 1 | tinkabot | 75421954-c8f7-4609-8e30-0721c5fe576a | Wrap an API into a Cursor/Agent plugin (MCP + skills), prove locally, then publish to Marketplace / cursor.directory | Marketplace | None direct. Closest: Senior Developer (product code). Not in GROUPS.md. |
| 2 | SWE | cfbb15f3-8d17-460d-aef4-18a71ddf2624 | Cursor's software engineer: code, issue triage, PR review, prod investigation; briefs from Chief Thunderstone only | Marketplace | HIGH with Senior Developer, Lingxi's Engineer Bot, Nightly Audit Engineer (all BUILD coders) |
| 3 | Engineering Lead | d298c7a0-0f31-4ecc-afef-4643c1278320 | Owns the loop: splits work into Cloud Agents, chases CI/reviews on a weekday cadence, pings on blocked/ready/done | Marketplace | HIGH with Chief Thunderstone (BUILD lead), Lingxi's Engineer Bot (supervisor), Projects Manager. Not in GROUPS.md. |
| 4 | Nightly Audit Engineer | 08a36657-cc50-4461-945a-f4d7cb3de443 | Research one codebase area, propose one cleanup per area; Runner brief via Chief, DT-triggered | Marketplace | MED with SWE, Senior Developer, Git-Scout (PR path) |
| 5 | Lingxi's Engineer Bot | 81e154c6-b03a-4c31-82d1-1b767937d967 | Engineering supervisor: boards work, PR review, asks DT only to merge; event-triggered | Marketplace | HIGH with SWE, Chief Thunderstone, Projects Manager |
| 6 | Tradbot | 4b5e2379-a6c8-4da7-885a-ffe25646c52c | Personal admin: personal email/calendar, school forms/bills/RSVPs, drafts only | Marketplace | MED with Executive Assistant (work lane vs personal lane; profile splits them) |
| 7 | Projects Manager | 7b71c6ec-6579-4f3f-92bc-64406b98f4dc | Runs DT's projects from GitHub Project #2 "Thunderstone"; decides status, never does specialist work | Marketplace | MED with Chief Thunderstone (task routing) and Grok Bot (CONTROL) |
| 8 | dr eggbot | eaac08b1-1c4a-43b3-8b9c-57f97c9d818d | Designs Grok Bots; CreateAgent only on DT's yes; reports to Grok Bot | Marketplace | None (unique). Not in the named roster list. |

Roster members NOT in Marketplace: Chiefs section = Chief Thunderstone, Chief Lorekeeper, Grok Bot, Chief of Staff (retired), `ebc373c6-...` (no folder on disk). Grunts = Cursor-Runner, Git-Scout, Senior Developer, Researcher, Executive Assistant, `fc82f65b-...` (no folder on disk).

## Routines / automations on disk (event-only check)

- No Marketplace bot has an `automation.json`. Only Projects Manager has an `automations/` dir, and it is empty. `automation_completion_inbox` is empty for all 8. No cron/time-based routine found => no event-only violation on disk.
- Cron-style routines on disk belong to bots outside this section (Chief of Staff, Chief Lorekeeper, Chief Thunderstone, Executive Assistant, Git-Scout dir): not covered here.
- Text-level violation: Engineering Lead's profile says it works "on a weekday cadence" and spawns Cloud Agents. That conflicts with event-only and with Lingxi's/Standard "no cloud agents / no sub-agents".
- Caveat: platform-side routines (scheduler) may exist that are not mirrored on disk; I could not see them. Confirm in the app.

## House-standard gaps (per bot)

Reference: STANDARD-PROFILE-BLOCK-SHORT.md (10 rules, 894 chars). Findings from profile text only.
Per-bot MCP grants are NOT on disk (`mcpBoxServers` = [], `mcpDisabledToolsByServerId` = {} in settings.json; per-bot settings.json only has `notifyOnAgentUpdates`). So Serena/GitHub/GitLab/Githits/Context7 access cannot be verified from disk; check in the app.
Common to all 8: standard rule 3 lists no GitLab or Githits; granting those is a settings/tool step, not a profile step.

Six bots (SWE, Nightly, Lingxi, Tradbot, Projects Manager, dr eggbot) already carry the LeanCTX strict + Caveman bot-to-bot + event-only lines. Five of them (all but dr eggbot) carry the older rule-7 wording ("No send/post/commit/push/delete/buy without DT's exact approval") rather than the new "Law (DT 10-10)" wording in the standard file. Their rule 1/2/4 wording is also the longer variant, not byte-identical to the SHORT block.

1. tinkabot (code bot): 196-char profile, no standard block. Needs: full 10-rule block (LeanCTX, Caveman, event-only, Chief routing, health.sh); one-job/anti-jobs; publish step ("ask once, publish to Marketplace/cursor.directory") must be gated by DT approval and routed via Chief; code MCP set (Serena, GitHub, GitLab, Githits, Context7). Consider merge/retire vs Senior Developer unless DT wants plugin-publishing as a job.
2. SWE (code bot): 1370 chars, has block incl. LeanCTX, Caveman, event-only, Chief-only. Needs: swap rule 7 to the DT 10-10 Law wording; code MCP set incl. GitLab + Githits (rule 3 doesn't list them); confirm no polling routine on the platform. Overlap: merge candidate with Lingxi's/Senior Developer. Already has patch note `swe.patch.md`.
3. Engineering Lead (code/orchestration): 230-char profile, no block. Conflicts: Cloud Agents, weekday cadence. Needs: full block, rewrite to event-only (alerts/PR/CI events), remove Cloud Agent spawning (route to Runner via Chief), report to Chief Thunderstone only. Superseded 2026-10-10: DT kept it as SWE Tribe lead; see engineering-lead.patch.md.
4. Nightly Audit Engineer (code bot): 1321 chars, block present, explicit event-only (no 4am default), Runner brief via Chief. Needs: rule 7 wording; code MCP set (Serena/GitHub/GitLab/Githits/Context7). Name "Nightly" is misleading vs event-only; consider renaming or folding into SWE. Patch note exists.
5. Lingxi's Engineer Bot (code bot): 1346 chars, block present, event-only, no CloudAgent, Chief-only. Needs: rule 7 wording; code MCP set. Superseded 2026-10-10: DT kept SWE and Lingxi's as SWE Tribe members (Lingxi's = CI/CD and PR gates). Patch note exists.
6. Tradbot (non-code): 1332 chars, block present, no routines, no workers. Needs: rule 7 wording only. Code MCP set not required. Note: "Watches personal email and calendar" is on-demand only under "no routines"; make sure no polling is configured on the platform. Reports to Grok Bot (matches GROUPS.md).
7. Projects Manager (non-code, reads GitHub): 1387 chars, block present, "no routines", empty automations dir. Needs: rule 7 wording; GitHub only (+ Context7). Keeps `timeout 30 gh api graphql`. Chief routing: requests go Grok Bot -> Chief; compliant.
8. dr eggbot (non-code, designer): 1232 chars; recipe references STANDARD file rather than embedding the block; lacks the verbatim 10 rules. Needs: embed the block (or accept the read-at-first-turn pointer), keep CreateAgent gated on DT yes. No code MCP needed.

## Suggested consolidation (for Grok Bot/DT decision; nothing done)
- BUILD coder overlap: SWE, Lingxi's Engineer Bot, Nightly Audit Engineer, Engineering Lead, tinkabot, Senior Developer. (Superseded 2026-10-10: DT kept SWE, Lingxi's and Engineering Lead as the SWE Tribe.) Fold Nightly Audit into a Runner brief template; tinkabot only if DT wants plugin publishing.
- Tradbot vs Executive Assistant: keep separate only if DT wants the personal/work split; otherwise merge.
