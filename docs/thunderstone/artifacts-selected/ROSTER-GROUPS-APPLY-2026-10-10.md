# ROSTER-GROUPS-APPLY — 2026-10-10

Worker: Cursor-Runner. Requester: Grok Bot (DT approved) via Chief Thunderstone.
Rules kept: files only; no stage/commit/push/PR; no profile edits; no cron/timer/routine; no secrets. Starter HEAD 4429619, `git status --short` empty.

## Part A — Cursor login smoke: NOT VALID (auth OK, task not executed)
Checks (this shell, PATH incl ~/.local/bin):
- `agent status` -> "Logged in as DT" (now consistent; earlier "Not logged in" no longer reproduces)
- `agent about` -> CLI 2026.10.01-e373342 (up to date), Subscription Tier **Pro**
- `agent models` -> works (auto, gpt-5.3-codex-*, ...)
Run (once): detached tmux `cursor-smoke3`: `cd starter && env -u CURSOR_AGENT bash scripts/run-task.sh BRIEF-CURSOR-CLI-SMOKE-2026-10-10.md` (trust persisted; no --trust).
Log: $WORKSPACE/thunderstone/artifacts/cursor-cli-smoke-20261010-run3.log — last line `exit=0`; usage-limit text count 0; NO auth error. The model replied, so login/plan/limit are fine.
BUT the agent did no work: report file workspace/reports/cursor-smoke-20261010.md NOT refreshed (mtime still 17:27:54 from the earlier run). Valid-by-brief = exit 0 AND report refreshed AND no limit text -> fails the middle test.
Cause (agent's own words, excerpt): it could not read the brief because every read path (Read tool, shell cat) was rerouted through lean-ctx and returned a "file unchanged" stub; lean-ctx's own read call was rejected; grep blocked by a lean-ctx policy; base64 not on the allowlist. It changed no settings and wrote nothing. It also asked whether `workspace/reports` means $WORKSPACE/reports or reports/ inside the repo (brief says repo-relative).
Diagnosis: the global ~/.cursor/hooks.json lean-ctx preToolUse/observe hooks shadow reads for the headless agent. That is a config interaction, not an auth/plan/limit problem.
NOT retried (brief: one run, stop on failure). Smallest candidate fixes (untested, need DT/Grok Bot OK):
 1. Launch with `LEAN_CTX_DISABLED=1` in the env for the agent process only (documented in `lean-ctx --help`: bypasses compression and keeps the shell hook from loading). May not disable the Cursor-side preToolUse hook.
 2. Inline the brief text in the prompt (run-task.sh currently passes only a path), avoiding a file read.
 3. Make the starter's hook/shadow config project-local opt-out (needs a read of lean-ctx docs; not attempted).
Option 1 is a one-line change to the tmux launch; recommend trying it as the single approved retry.

## health.sh --bg --force
exit 0; $WORKSPACE/thunderstone/state/health-last.json status **green** (resume ok, doctor ok, git_starter 0, gh ok, cursor=login-ok, disk 9%). No usage-limit flag file exists ($WORKSPACE/thunderstone/state/cursor-usage-limit absent). modme-ui-01 has 32135 changed entries (info only).

## Part B — see ROSTER-GROUPS-PARTB-2026-10-10.md (in progress)

## Part B — DONE (files only)
Detail + per-file char counts: $WORKSPACE/thunderstone/artifacts/ROSTER-GROUPS-PARTB-2026-10-10.md
Files in $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/: GROUPS.md, 14 <name>.patch.md (all <=1,600 chars; largest Git-Scout 1,599), STANDARD-PROFILE-BLOCK-SHORT.md (894 chars, all 10 rules), CAVEMAN-RULES.md, DREGGBOT-GUIDE.md (783-char section), ROUTINE-PAUSE-LIST.md.
Gaps: Drive handoff pack (PLAN/TOKEN-OPTIMIZATION/THUNDERSTONE-INTEGRATION) and Context7 NOT read (token saving) -> patches not reconciled with it. New bot SWE (cfbb15f3) has no patch/group yet. Grok Bot profile length limit unknown. Caveman = JuliusBrussee/caveman (README verified); rapchic/cavecrew unverified. No placeholder 'New Bot'/'New Agent' profile.json found; empty room dir fdc323ab = delete candidate (DT).
No stage/commit/push/PR, no profile edits, no routines.

## Part A retry (approved by Chief, one retry) — 2026-10-10 19:13 AEDT: VALID (with caveat)
Launch: detached tmux `cursor-smoke4`, `bash /tmp/cursor-smoke-retry2.sh` = `env -u CURSOR_AGENT LEAN_CTX_DISABLED=1 agent -p "<instructions + brief text inlined>"` from $WORKSPACE/thunderstone-starter (run-task.sh unedited). Log: $WORKSPACE/thunderstone/artifacts/cursor-cli-smoke-20261010-run4.log
Result: log tail `exit=0`; no usage-limit/auth text. Artifact changed: workspace/reports/cursor-smoke-20261010.md mtime 17:27:54 -> 19:14:21, content rewritten with 6th line `Run: retry LEAN_CTX_DISABLED=1`. Excerpt: "Branch: main (tracking origin/main); HEAD 4429619 / git status --short count = 0 / scripts/ (19): ... / AGENTS.md: present".
Independent check by Runner: live `git status --short` = 0 lines, HEAD 4429619 -> report facts correct.
Caveat: in `-p` mode (no --force) the agent's shell tool was rejected, so it read .git files instead of running git; the status count came from a session snapshot, not a live command. Running shell commands from headless agent needs approval flags (e.g. --force/--auto-review) — a DT decision, not applied.
Cause of the earlier failure confirmed: lean-ctx read shadowing; LEAN_CTX_DISABLED=1 plus inlined text fixed file access. run-task.sh would need the same env var (or inline text) to work unchanged; NOT edited.

## SWE (cfbb15f3)
Added groups/swe.patch.md (1,371 chars, BUILD, reports to Chief only, event-triggered, standard 10 rules) and a BUILD row in groups/GROUPS.md. No profile edited. Nothing deleted (empty room dir fdc323ab stays; DT decides).
Commit/push/PR: not performed. Starter `git status --short` empty.
