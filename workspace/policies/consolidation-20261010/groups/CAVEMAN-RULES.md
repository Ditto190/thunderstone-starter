# Caveman rules (2026-10-10)

## What Caveman is (verified)
- Source: github.com/JuliusBrussee/caveman (README read 2026-10-10; not under Ditto190, and no Ditto190 repo of that name was found). Apache-2.0. "Caveman is a voice, not broken grammar": a terse style skill (`/caveman`, `/ultracave`, `/megacave`) plus an optional CLI/proxy (`caveman shrink`, `caveman browse`) that compresses what an agent reads. Claimed savings (their numbers, unverified here): ~65% fewer output tokens on prose; 33.2% fewer input tokens via the proxy.
- Style rules from the README: answer first, no greeting/recap/"hope this helps"; one idea per sentence (<=20 words, active voice); articles may go, but not/never/no/only never go; numbers and units exact; code, commands, paths and error messages verbatim; quiet tool runs; full sentences for security warnings, irreversible actions, step orders and questions; plain wins if caveman is not shorter; never rewrite the user's prompts.
- cavecrew: github.com/rapchic/cavecrew, "Token-efficient subagent delegation for long AI coding sessions" (0 stars). README not read (only the page summary), so its behaviour is unknown. The Caveman README also lists a `cavecrew` item: subagents that find/edit/review code and report in caveman. Not used here: our rules forbid sub-agents unless a brief asks.
- Thunderstone's own wording: AGENTS.md "Caveman tone is explicit opt-in and must never alter commands or safety clarity". Whether any Caveman tooling is installed on the VM: unknown (not checked; no install in scope).

## Allowed scope (Thunderstone)
- ONLY bot-to-bot messages (SendToAgent replies, evidence-file summaries between bots), opt-in per brief.
- Use the README style: answer first, <=20-word sentences, drop filler.

## Forbidden scope
- Anything to DT: always normal en-AU prose.
- Commands, file paths, code, error text, IDs, URLs: written in full, verbatim.
- Approvals, send/commit/push/delete/purchase requests, safety or security text, usage-limit blockers, and anything with a negation that matters: full sentences.
- Briefs and profile text (prompts stay normal prose; the README notes caveman-ing prompts backfires).
- No theatrical "me think" phrasing. No installing the proxy/CLI or sending its telemetry from this VM without DT's approval.
