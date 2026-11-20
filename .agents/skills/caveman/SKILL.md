---
name: caveman
description: >-
  Terse style for bot-to-bot and group-chat messages, status pings and internal
  notes only. Never for user-facing finals, approvals, warnings or ambiguous text.
---

# caveman (official, v4.0.1, house-restricted)

Source: https://github.com/JuliusBrussee/caveman (Apache-2.0, owner JuliusBrussee)
Commit: d262ab3882952a59312ff3537cd86d894523c5ab (2026-10-13), tag v4.0.1.
Skill: `skills/caveman/SKILL.md` @ 9a940445. "§N" = Rules section N there.

## When to use
- Bot-to-bot or group-chat messages, status pings, internal notes (house-rules 9).
- Not for: final answers, approvals, warnings, questions to the user, or any
  text persisted outside chat (code, comments, commits, docs, PRs).

## Steps
1. Answer first: `[thing] [action] [reason]. [next step].` (§1)
2. Kill ceremony: no greeting, recap, closer or "Sure!" (§2).
3. Short standard words. No invented abbreviations (cfg, impl) (§3).
4. Drop articles only if the sentence still reads in one pass. Never drop
   not, never, no, only, except (§4).
5. Payload verbatim: code, commands, paths, IDs, numbers, errors (§6).
6. One fact per line. Silent when there is nothing new (house-rules 2).
7. Pre-send check (SKILL, Pre-send check): no announce-first, no closing recap,
   negations and payload intact, no double-reading sentences.

## Hard exits: write plain English
Official triggers (SKILL, When to break the rules):
1. Security warning. 2. Irreversible action. 3. Step order a fragment could
   scramble. 4. User confused or repeats a question. 5. Anything persisted
   outside chat. 6. Harness asks for a status line. 7. Question or options for the user.
House extension: approvals, push/deploy/send requests (house-rules 9).

## Anti-patterns
- "Caveman:" prefix, "me think", or any performing of the voice (§9).
- Normal answer plus caveman copy (§9).
- Caveman in user-facing finals or approvals (house rule).
- Shortening existing code comments you were not asked to change (§6).
- Expecting large savings. Official measure: caveman ~3% fewer output tokens
  than a concise control, within noise (skills/caveman/README.md, What it does).
  Use it for clarity-neutral brevity, not as a cost lever.
