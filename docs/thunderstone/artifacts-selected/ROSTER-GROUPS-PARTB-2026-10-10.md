# ROSTER-GROUPS Part B evidence (2026-10-10)
Dir: $WORKSPACE/thunderstone/policies/consolidation-20261010/groups (files only; no UpdateAgent, no git, no cron)

| file | chars |
|---|---|
| CAVEMAN-RULES.md | 2294 |
| DREGGBOT-GUIDE.md | 1744 |
| GROUPS.md | 2713 |
| ROUTINE-PAUSE-LIST.md | 2342 |
| STANDARD-PROFILE-BLOCK-SHORT.md | 895 |
| chief-lorekeeper.patch.md | 1598 |
| chief-of-staff.patch.md | 275 |
| chief-thunderstone.patch.md | 1585 |
| cursor-runner.patch.md | 1556 |
| dr-eggbot.patch.md | 1233 |
| executive-assistant.patch.md | 1557 |
| git-scout.patch.md | 1599 |
| grok-bot.patch.md | 1587 |
| lingxis-engineer-bot.patch.md | 1347 |
| nightly-audit-engineer.patch.md | 1322 |
| projects-manager.patch.md | 1388 |
| researcher.patch.md | 1586 |
| senior-developer.patch.md | 1544 |
| tradbot.patch.md | 1333 |

Char-limit: all `.patch.md` <=1.6k (1.2k-1.6k; grok-bot 1587, git-scout 1599) except none over; chief-of-staff 275 (retired). STANDARD-PROFILE-BLOCK-SHORT.md 895 (<=900, all 10 rules incl. strict LeanCTX). DREGGBOT-GUIDE section 783 (<=1.2k).
Generator: $WORKSPACE/thunderstone/artifacts/_groups_gen.py (grok-bot patch was later hand-trimmed with sed).

## Sources used
- profile.json name/title/description for all 15 agent dirs; ROUTINE-AUDIT.md, ROSTER-AND-ROUTING.md, STANDARD-PROFILE-BLOCK.md; automations dirs; JuliusBrussee/caveman README (WebFetch); rapchic/cavecrew page summary.
- GitHub Project #2 (Ditto190, title "Thunderstone") via timeout gh api graphql: 0 items returned (empty, or items not visible to this token).
- NOT read (token cap): Drive 00_INBOX/Thunderstone, Grok-Bot-Ops-Handoff-Pack-20261010 files, Context7.
- xAI docs search for profile length limit: no result.

## Open questions for DT
1. Delete "New Bot"/"New Agent" placeholders (no ids on disk; need UI) and the "Thunderstone Clan" room fdc323ab (empty description)?
2. EA weekly investment Gmail scan: keep (time-based) or make on-demand?
3. Lingxi/Nightly: confirm no server-side routines exist (not on disk).
4. Grok Bot's own periodic routine: not found on disk; check UI.
5. Board: Project #2 shows 0 items; is it populated elsewhere (org-owned)?
6. Design Partner (named in CoS profile) has no agent dir; ignore?

## Unknowns
- Grok Bot profile max length (no docs hit; 1.6k is house target only).
- What cavecrew does (README unread); whether Caveman is installed on the VM.
- Drive handoff pack content not reconciled with these patches.
