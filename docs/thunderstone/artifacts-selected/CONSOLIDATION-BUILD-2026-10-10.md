# Consolidation build evidence, 2026-10-10 (Worker: Cursor-Runner)
Brief: $WORKSPACE/thunderstone/briefs/BRIEF-CONSOLIDATION-BUILD-2026-10-10.md. Times in AEDT (Sydney).
Commit/push/PR: **not performed.** No `agent` run for work (only read-only `agent status|about|models`, no model prompt, no credits). No `lean-ctx allow` was needed (none recorded). No secret values written.

## 1. LeanCTX adaptive learning: verified facts
Sources: https://leanctx.com/docs/concepts/adaptive-learning/ (concept page: no commands, "Exact commands ... belong to versioned references"); https://leanctx.com/docs/configuration/ ; https://leanctx.com/docs/cli-reference/ ; https://leanctx.com/docs/concepts/read-modes/ ; https://leanctx.com/docs/journeys/customization-and-governance/ ; https://leanctx.com/docs/operations/ ; local `lean-ctx 3.10.2` (`help all`, `config schema`, `learning status`). Context7 was **unavailable** (monthly quota exceeded), so official docs and the installed CLI were used instead.
- Config key (verified in docs and `lean-ctx config schema`): `auto_mode_learning` (bool, default false, env `LEAN_CTX_AUTO_MODE_LEARNING`). Opt-in; lets predictor, bandit, heatmap, adaptive policy and bounce/path memory influence `auto` read mode. Off keeps output byte-stable for prompt caching. Both `~/.config/lean-ctx/config.toml` and `$WORKSPACE/.lean-ctx.toml` already set it to true.
- Commands (verified): `lean-ctx learning [status|export|import]` (CLI reference marks `learning` and `learn` as **Research**: "not autonomous optimization"); `lean-ctx learning export team.json` shares a secret-free bundle. `lean-ctx learning status` here: no learned thresholds yet; bounce rate 0.0% (last 7d, n=647).
- Read modes (verified): `lean-ctx read <file> -m map|signatures|full`, `-m full --fresh`. Shell: `lean-ctx -c "<cmd>"` compressed, `lean-ctx raw "<cmd>"` / `-c --raw` uncompressed. `lean-ctx compression <off|lite|standard|max>` (alias `terse`). `lean-ctx config show|schema|validate|set <k> <v>`.
- Concept page: propose, evaluate against baseline, authorise, apply and observe; "the optimizer proposes, the host authorises".
- UNVERIFIED / caveats: (a) the GitHub reference doc (docs/reference/18-adaptive-learning.md) returned empty on fetch; its content was only seen via a search snippet; (b) `lean-ctx read -m map` on a `.sh` file returns "no extractable structure", so map/signatures help for code, not shell scripts; (c) the learning feature is documented as Research, so treat gains as unproven; (d) `lean-ctx` logs a WARN that `.lean-ctx.toml` overrides (custom_aliases, tool_profile, etc.) are ignored until `lean-ctx trust` is run in $WORKSPACE/modme-ui-01 (not actioned); (e) exact per-version CLI reference pages beyond the cli-reference index were not read in full.

## 2. health.sh + test
New: $WORKSPACE/thunderstone/scripts/health.sh, $WORKSPACE/thunderstone/scripts/tests/health-test.sh (plain bash; bats is not installed, not installed by me).
- Behaviour: TZ=Australia/Sydney weekday-only (Sat/Sun silent exit 0). Checks (each wrapped in `timeout ${HEALTH_TIMEOUT:-20}`): starter `resume.sh` (note: only ensures the tmux session exists, the one non-read-only side effect the brief asked for), `doctor.sh`, `git status --short` counts (starter, modme-ui-01; informational), `gh auth status`, `agent status`, disk (fail >=90%), memory (fail <300MB). Green: silent, exit 0, one line appended to reports/health-YYYYMMDD.log. Fail: writes artifacts/HEALTH-FAIL-<ts>.md, prints <=5 lines, exit 1.
- Overrides: HEALTH_FORCE_DAY (ISO weekday), HEALTH_FORCE_FAIL=1, HEALTH_SKIP=resume,doctor,git,gh,agent,disk,mem, HEALTH_LOG_DIR, HEALTH_ARTIFACT_DIR, HEALTH_STARTER, HEALTH_MODME, HEALTH_TIMEOUT.
- Usage-limit handling: no credit-free probe exists (`agent status` only reports login; a limit only appears on a real run, and `agent models` returned "Authentication required" in this shell even though `agent status` says logged in; flagged, not diagnosed). So health.sh reports the condition (non-fatal WARN in the log line) if `agent status` mentions a limit or the flag file $WORKSPACE/thunderstone/state/cursor-usage-limit exists (whoever hits a limit should touch it; not created by me). It never crashes on it and never sends a prompt.
- Real run, forced weekday, temp log dir: `GREEN resume=ok doctor=ok git_starter=0 git_modme=32135 gh=ok cursor=login-ok disk=9% mem=4172MB`, exit 0. Real run today (Saturday): silent, exit 0, no log. Observation: modme-ui-01 has 32135 changed entries; reported only, not a failure.
- Tests (15 assertions): weekend skip; green silent/one log line/no artifact; forced fail non-zero/<=5 lines/artifact/log; missing repo dir fails; two green runs idempotent. Result: **passed=15 failed=0, exit 0**. No real log or HEALTH-FAIL artifact was created (tests and demo used temp dirs).

## 3. Policy updates
Modified: policies/consolidation-20261010/STANDARD-PROFILE-BLOCK.md (11 lines incl. heading; rules 4, 8 and 9 new or changed) and ROSTER-AND-ROUTING.md ("DECISION NEEDED" section removed and replaced by "Cursor availability (decided by DT)"; new "Compression stack" section; heavy-work fallback rule). Trust marker confirmed present: ~/.cursor/projects$WORKSPACE-thunderstone-starter/.workspace-trusted. Diffs: artifacts/consolidation-orig/STANDARD-PROFILE-BLOCK.diff and ROSTER-AND-ROUTING.diff.

## 4. startup.sh
New: $WORKSPACE/thunderstone/scripts/startup.sh. Runs health.sh, then prints `START-HERE: $WORKSPACE/thunderstone/.context/START-HERE.md` (override START_HERE_PATH). `STARTUP_QUIET=1` = silent on green (use for the routine). Exit mirrors health.sh; on failure prints the health summary, then the pointer. Surfaces a WARN (e.g. Cursor limit) from today's log. Scheduling (documented in the script header): the box has no cron, so create ONE weekday routine owned by Chief Thunderstone (cron `10 8 * * 1-5`, Sydney) whose only instruction is to run `STARTUP_QUIET=1 bash $WORKSPACE/thunderstone/scripts/startup.sh`, stay silent on empty output, and on non-zero message Grok Bot once with the artifact path and <=3 lines. I did not create the routine.

## 5. Stale chain/role names (working tree only)
- $WORKSPACE/thunderstone-starter/AGENTS.md: modified (starter is a git repo; `git status --short` = ` M AGENTS.md`). Diff: artifacts/consolidation-orig/AGENTS.md.diff (below).
- $WORKSPACE/vm-ops/ORCHESTRATION.md: modified. $WORKSPACE/vm-ops is **not a git repo**, so the diff is against a pre-edit copy saved in artifacts/consolidation-orig/ORCHESTRATION.md.orig (below). Not changed: stale CLI version "2026.09.08" and thunder-agent/CURSOR_API_KEY notes (outside the brief; vm-ops/README.md also still says "CoS-corrected" and the old version; I briefly touched README.md by mistake, restored its text, but its mtime changed).

### AGENTS.md diff
```diff
--- AGENTS.md.orig	2026-10-10 16:36:20.399158736 +1100
+++ $WORKSPACE/thunderstone-starter/AGENTS.md	2026-10-10 18:13:30.655636474 +1100
@@ -19,8 +19,9 @@
   (see `.cursor/rules/multi-agent-worktrees.mdc`). No blind parallel agents.
 - Inside Cursor CLI/Cloud, execute directly. Never recursively invoke an agent.
 - Work on a branch and open a PR. Never push to `main` or change rulesets.
-- Roles: Chief of Chiefs routes tasks, Thunder-Terminal owns the VM, Cursor-Hammer implements,
-  Watcher of Broken Things verifies, Keeper of Stone Tablets keeps briefs and handoffs.
+- Roles: Grok Bot (primary) is the front door and router; Chief Thunderstone is the sole execution lead for the VM;
+  Cursor-Runner implements via the Cursor CLI; Git-Scout is the git gate (approved writes only);
+  Chief Lorekeeper keeps briefs, wiki and handoffs on demand.
 
 ## Safety
 - Do not auto-approve MCP or shell, push, deploy, delete remote data, or message others.
```

### ORCHESTRATION.md diff
```diff
--- ORCHESTRATION.md.orig	2026-10-10 16:35:14.795158736 +1100
+++ $WORKSPACE/vm-ops/ORCHESTRATION.md	2026-10-10 18:13:35.539636474 +1100
@@ -1,10 +1,10 @@
-# VM Ops orchestration (CoS-corrected 2026-09-11)
+# VM Ops orchestration (chain updated 2026-10-10)
 
 ## Chain of command
-DT → **Chief of Staff** (first POC / chief of chiefs) → **Chief Terminal-Thunder** → Cursor-Runner / Git-Scout
+DT → **Grok Bot** (primary front door and router) → **Chief Thunderstone** (sole execution lead) → Cursor-Runner / Git-Scout
 
-- DT may still talk to Thunder directly for VM jobs; CoS oversees tribe health and config.
-- Grunts never freestyle intake with DT. Idle = quiet. Report only to Thunder (or VM Ops channel).
+- DT may still talk to Chief Thunderstone directly for VM jobs; Grok Bot oversees routing, priorities and escalation.
+- Grunts never freestyle intake with DT. Idle = quiet. Report only to Chief Thunderstone (or VM Ops channel).
 
 ## Local Cursor CLI (canonical)
 ```bash
@@ -19,8 +19,8 @@
 - Herder/Herdr: **not installed**
 
 ## Channels
-- **VM Ops** (`9c7ac16a`): Thunder + Cursor-Runner + Git-Scout
-- **A.D.A.M. Chiefs** (`408d3c41`): CoS + Thunder
+- **VM Ops** (`9c7ac16a`): Chief Thunderstone + Cursor-Runner + Git-Scout
+- **A.D.A.M. Chiefs** (`408d3c41`): legacy channel (Chief of Staff is hidden; Terminal-Thunder is superseded by Chief Thunderstone); use Grok Bot <-> Chief Thunderstone 1:1 instead
 
 ## Delivery defaults
 Uncommitted working tree + evidence. No `git add -A`, no push/PR/deploy without DT exact approval via Git-Scout.
@@ -28,5 +28,5 @@
 ## Known failure modes (fixed / to avoid)
 1. Bare `agent` without PATH → use absolute `thunder-agent` or `vm-ops-env`
 2. Missing `CURSOR_API_KEY` in non-interactive shells → always use `thunder-agent`
-3. Grunts freelancing scouts/jobs → profiles now hard-block; Thunder must assign
+3. Grunts freelancing scouts/jobs → profiles now hard-block; Chief Thunderstone must assign
 4. Empty channel description on VM Ops group agent shell — operational channel is group.json members list
```

## 6. ROUTINE-AUDIT: ready-to-apply pause list (I cannot pause other bots' routines)
Verified on disk (~/agent-data/agents/<id>/automations/*/automation.json, all enabled, Sydney weekday cron). Replacement: health.sh via startup.sh (item 4) as ONE routine.
| Owner (agent id prefix) | Routine | Cron | Action |
|---|---|---|---|
| Chief of Staff (437fcfe8) | Thunderstone weekday CLI health | 15 8 * * 1-5 | PAUSE (the 08:15 item) |
| Chief of Staff (437fcfe8) | Thunderstone PM CLI pulse | 15 16 * * 1-5 | PAUSE (duplicate git status/ls) |
| Chief Thunderstone (45e99bd6) | VM morning resume+doctor | 20 8 * * 1-5 | PAUSE (the 08:20 item), then recreate as the single startup.sh routine |
| Chief Thunderstone (45e99bd6) | Runner terminal smoke brief | 30 10 * * 1-5 | PAUSE (the 10:30 Runner smoke; covered by health.sh) |
| Git-Scout (08fb189f) | Weekday lean git status | 30 16 * * 1-5 | PAUSE (the 16:30 item); wake Scout only on dirty/unexpected remote |
| Chief Lorekeeper (e7b5b3b8) | Lorekeeper Drive freshness pulse | 0 15 * * 1-5 | PAUSE (daily Drive freshness check; run on demand or weekly) |
| Chief Lorekeeper (e7b5b3b8) | Lorekeeper morning context health | 25 8 * * 1-5 | PAUSE (folded into health.sh) |
| Chief Lorekeeper (e7b5b3b8) | Lorekeeper evening registry sync | 45 16 * * 1-5 | PAUSE (folded into health.sh) |
| Executive Assistant (f9067a3d) | Weekly investment Gmail scan | 0 8 * * 1 | KEEP (weekly, wanted) |
Bots with no routine files on disk (their owners or DT must disable in the routines UI): Lingxi's Engineer Bot "30-minute PR watch" (~48 runs/day, spawns paid CloudAgents): PAUSE, replace with a daily `gh pr list` inside health.sh later; Nightly Audit Engineer 4am whole-repo audit: PAUSE, run only as a briefed Runner job via Cursor CLI. Grok Bot's own periodic routine: not found on disk, parent to check the routines UI. Net: 8 weekday model runs/day become 1 script run, 0 model runs when green.

## Commands run and exit codes (from $WORKSPACE/thunderstone-starter unless stated)
| Command | Exit |
|---|---|
| `bash scripts/doctor.sh` | 0 |
| `npm test` (validate.sh: hygiene + infrastructure validation passed) | 0 |
| `npm run lint` (shellcheck scripts/*.sh) | 0 |
| `shellcheck health.sh startup.sh tests/health-test.sh` | 0 (after replacing `ls|wc` with `find`; first run had 4 SC2012 info notes) |
| `bash scripts/tests/health-test.sh` | 0 (15/15) |
| `bash scripts/health.sh` (real, Saturday) | 0, silent |
| `HEALTH_FORCE_DAY=3 ... health.sh` (real checks, temp dirs) | 0, GREEN line |
| `bash startup.sh` / forced-fail via startup.sh | 0 / 1 |
| read-only: `agent status` 0, `agent about` 0, `agent models` printed auth error, `gh auth status` 0, `lean-ctx learning status|config schema|help all` 0 | see left |

## State after
- Starter: HEAD 4429619 on main (unchanged). `git status --short`: ` M AGENTS.md`.
- $WORKSPACE/vm-ops: not a git repo (no status). $WORKSPACE/modme-ui-01: 32135 changed entries (pre-existing, untouched).
- New files: scripts/health.sh, scripts/startup.sh, scripts/tests/health-test.sh, artifacts/consolidation-orig/* (.orig copies and .diff files), this evidence file. Modified: STANDARD-PROFILE-BLOCK.md, ROSTER-AND-ROUTING.md, AGENTS.md, ORCHESTRATION.md.
- Commit/push/PR: not performed.
