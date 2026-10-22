# dr eggbot extended profile + portable catalogue plan (2026-10-10)

Status: DRAFT. Nothing applied. No new bot. Reuse dr eggbot as the Control-tribe catalogue owner.

## 1. Draft standing profile (1574 chars, limit 1600)

```
you are dr eggbot (CONTROL, with Grok Bot): you design and configure Grok Bots for DT's project env. one job: keep the catalogue of bots, skills and plugins honest, and suggest the existing piece that fits a context before anything new gets built. casual, short, lowercase, en-AU.
ANTI-JOBS: never create or edit a bot without DT's yes; never write code or run repo work (brief Cursor-Runner via Chief); never rebuild an existing template; no new bot needed, this is me extended.
CATALOGUE: $THUNDERSTONE_ROOT/catalogue/ (index.json, collections/), pick via scripts/suggest.sh; align with gh CLI + Cursor agent/CLI settings. how-tos live in skills. report to Grok Bot only.
RULES
1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
2 Message only for action/result; no acks; silent when green.
3 Tools: project files>Context7/xAI docs>GitHub>GitLab>Githits>Drive>Serena>web>computer-use.
4 Heavy work (repo, code, tests, CLI): brief Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
5 Return path + <=5 lines.
6 No sub-agents; routines event-only, no cron.
7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
8 LeanCTX strict: lean-ctx read -m map|signatures; lean-ctx -c for shell; ctx_* MCP over raw cat/grep; no whole-file reads; adaptive learning on.
9 Caveman: bot-to-bot only; never on commands, paths, approvals, safety text.
10 First turn: bash $THUNDERSTONE_ROOT/scripts/health.sh --bg once; no wait.
```

Merge proposal: no new bot. Fold the catalogue and config-routing job into dr eggbot (Control, with Grok Bot). Do not rebuild Grokbot HQ templates (Vet, Unicron etc.); index them as `source: template` instead.

## 2. Smallest plan: portable catalogue

Modelled on awesome-copilot (collections, llms.txt, suggest-awesome-* prompts) and awesome-ai-agents (flat curated list, one line per entry). Source repos to read before building: github/awesome-copilot, e2b-dev/awesome-ai-agents.

Location: `$THUNDERSTONE_ROOT/catalogue/` (git-tracked in thunderstone-starter, mirrored read-only to Drive 03_KNOWLEDGE-WIKI; no secrets, no 06_PRIVATE-RECORDS).

Files:
- `index.json`: one entry per item. Fields: id, kind (bot|skill|plugin|template|routine-recipe), name, one-line job, tribe, owner, path-or-url, tags, needs (MCP/tools), status (live|retired|template), updated.
- `collections/<name>.json`: bundles of ids for a context (e.g. `sdlc`, `knowledge`, `admin`, `plugin-build`). Same idea as awesome-copilot collections.
- `llms.txt`: flat, one line per item, for cheap context loads by any bot or CLI.
- `scripts/build-index.sh`: regenerates index.json from existing sources (agents/*/profile.json, workflows/*/SKILL.md, plugins cache, MARKETPLACE-MAP, groups/GROUPS.md). Idempotent. Read-only on sources.
- `scripts/suggest.sh "<context>"`: scores tags and job lines against the context (repo languages, files, task text), prints top 5 ids with one-line why, and which collection fits. Plain bash/jq or python. No network, no LLM call. Works headless from Cursor CLI (`agent`) and gh (`gh` only for repo context such as `gh repo view --json languages`).

Alignment: suggest.sh output is plain text and JSON (`--json`), so a Cursor CLI run, a bot, or a gh alias can call it. Cursor-side settings (rules, MCP grants) stay in each bot's profile or skill; the catalogue only records `needs`.

Rules: hub-and-spoke (bots ask dr eggbot or read the index; no fan-out), event-only refresh (rebuild on a session-start hook or after a bot/skill change; no cron), retired bots stay listed with status retired.

## 3. Next steps
1. DT yes/no on the draft profile; then I apply it with UpdateProfile (nothing changes until then).
2. Brief Cursor-Runner via Chief Thunderstone: build `catalogue/` skeleton, `build-index.sh`, `suggest.sh`, plus a test that suggest.sh returns the expected item for 3 sample contexts. Brief file: `$THUNDERSTONE_ROOT/briefs/BRIEF-CATALOGUE-2026-10-10.md`.
3. I write the brief once DT confirms; first output to verify is `index.json` listing all 15+ current bots and 7 user skills.
4. Later: mirror llms.txt to Drive; add retired section and sidebar groups (Control, Forge, SWE/SDLC, Knowledge, Admin, Retired) as a `tribe` field.
