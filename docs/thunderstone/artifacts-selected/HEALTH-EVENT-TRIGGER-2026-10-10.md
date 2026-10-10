# Health check: event-triggered, non-blocking (2026-10-10, Australia/Sydney)

Worker: Cursor-Runner. Brief: $WORKSPACE/thunderstone/briefs/BRIEF-HEALTH-EVENT-TRIGGER-2026-10-10.md (read in full via Shell with LEAN_CTX_RAW=1, because the compressed view hides most of the file).
Commit/push/PR: not performed. No cron, timer, systemd, at job or routine was created. No secret values printed or written.

## Changed paths
- $WORKSPACE/thunderstone/scripts/health.sh (rewritten; weekday guard removed; `--bg`, guard, usage-limit flag added)
- $WORKSPACE/thunderstone/scripts/tests/health-test.sh (updated; 41 assertions)
- ~/.cursor/hooks.json (sessionStart entry merged in; backup at ~/.cursor/hooks.json.bak.20261010)
- $WORKSPACE/thunderstone/policies/consolidation-20261010/STANDARD-PROFILE-BLOCK.md (now 12 lines)
- $WORKSPACE/thunderstone/scripts/startup.sh (header only)
- New: $WORKSPACE/thunderstone/state/ (health-last.json, health-last-green, sessions/, backups-20261010/ holding pre-edit copies of the four repo-side files)
- Also written by the verification run: $WORKSPACE/thunderstone/reports/health-20261010.log (one GREEN line), reports/health-bg.out (empty)
Starter repo `git status --short` ($WORKSPACE/thunderstone-starter, HEAD 4429619): ` M AGENTS.md` only (unchanged).

## Task 1: health.sh
- Removed `date +%u` / HEALTH_FORCE_DAY / weekend skip. No day or time logic remains.
- `--bg`: checks the guard, then `setsid nohup bash health.sh --worker` detached with stdin/stdout/stderr redirected; exits 0 printing nothing. Measured 0.025 s for the hook invocation.
- Worker writes state/health-last.json (status, ts, epoch, session_id, artifact, fails, warns, notes) and the existing log line in reports/health-YYYYMMDD.log. Silent when green. On failure it writes artifacts/HEALTH-FAIL-<ts>.md.
- Guard (`--bg` only; foreground and `--force` always run): skip if state/sessions/<id>.marker exists, or state/health-last-green is younger than HEALTH_MIN_INTERVAL_MIN (default 30), or a worker lock is under 5 min old. Session id comes from HEALTH_SESSION_ID or `session_id`/`conversation_id` in the hook JSON on stdin (read with a 0.5 s cap, only if stdin is not a terminal). Markers older than 2 days are pruned on each `--bg` call (housekeeping on an event, not a schedule).
- Usage-limit flag state/cursor-usage-limit: created when `agent status` output matches limit wording; also created by `health.sh --scan-agent-output < text` (for a run-task wrapper to pipe real agent output into). Cleared when a later `agent status` check passes.
  Caveat: `agent status` cannot see a limit that only appears on a real run, so a clear means "login OK and no limit wording", not "limit reset". The flag is optimistic on clear.
- Added HEALTH_AGENT_BIN and HEALTH_STATE_DIR overrides so tests use fake agents and temp dirs.

## Task 2: ~/.cursor/hooks.json
Keys before: hooks{preCompact(1), preToolUse(4), sessionStart(1)}, version.
Keys after: same, sessionStart now 2 entries; all other keys byte-identical (checked with jq -S diff after removing sessionStart).
Added entry: command `bash $WORKSPACE/thunderstone/scripts/health.sh --bg`, failClosed false, timeoutSec 5, plus `timeout` 5.
Why both: the brief and the modme ADR use `timeoutSec`, but Cursor's hooks docs list `timeout` (seconds) as the supported key; `timeoutSec` is not documented. Both are present so the 5 s cap holds either way.
jq validation: before exit 0, after exit 0. File mode kept 0600. Original lean-ctx sessionStart entry untouched.
Verification: invoked the hook command directly with a sessionStart-shaped JSON on stdin (`session_id` verify-20261010-hook): exit 0, 0.025 s, no output. About 1 s later the worker wrote health-last.json status=green (resume, doctor, git, gh, cursor login, disk, mem all ok), one GREEN log line, no HEALTH-FAIL artifact. A second invocation with a different session id within 30 min was skipped by the guard (log stayed at 1 line).
UNVERIFIED in a live session: no fresh Cursor `agent` session was started (account is at its usage limit; I did not run `agent` for work). Whether Cursor loads this user-level entry and passes `session_id` on stdin in a live session is untested. Per the docs, sessionStart fires on new composer conversations, is fire-and-forget, and does not fire in cloud agents. Docs also say hooks are reloaded automatically on save.
Side effect of verification: real state now holds a green marker, so `--bg` is skipped for 30 min from 18:23 AEDT (use `--force` to override).

## Task 3: policy and startup header
- STANDARD-PROFILE-BLOCK.md: added rule 10 (run `bash $WORKSPACE/thunderstone/scripts/health.sh --bg` once at session start or first work turn; non-blocking, do not wait; read state/health-last.json only on failure or if a task needs the VM; never create cron or time-based routines). To stay at 12 lines I did not add a line beyond that. I also edited two existing phrases: heading "11 lines" to "12 lines", and rule 6 "Routines: silent when green, weekday only (Australia/Sydney)" to "Routines: event-triggered only, silent when green" (the old wording contradicted the no-time-based rule). Revert from state/backups-20261010/ if unwanted.
- startup.sh: header now describes event triggers only (Cursor sessionStart hook; bots run `--bg` on the first work turn; guard; manual foreground variant). Scheduling/cron advice removed. Script body unchanged.

## Task 4: routines skill (read-only; no routine created)
Source: ~/agent-data/managed-skills/skills/routines/SKILL.md. Trigger shapes: slack (mention/keyword/message/reaction), github (pr-opened, pr-pushed, pr-merged, pr-closed, review-*, pr-comment, inline-review-comment, review-thread-*, issue-assigned, ci-passed, ci-failed; per repo), origin (same PR/CI event family for native Origin repos), microsoftTeams (channel messages), linear (issueCreated, statusChanged, endOfCycle), sentry (issue events), pagerduty (incident events), email (mail arriving at a Grok Bot inbox), webhook (outside POST to the routine's URL), group (several listeners, any one fires), and cron (schedule; the only time-based shape).
None fires on a new session or new turn. Nothing in the skill offers a session-start/turn-start event. The closest are `webhook` (something external must POST) and `email` (needs mail), both of which require an outside sender, so they do not fit. Conclusion: for Grok Bot bots the event is the bot's own first work turn, run via rule 10 of the profile block. Cursor's own sessionStart hook covers the Cursor CLI/IDE only.
(Lines 28 of the skill were partly cut in my output; they cover the Origin trigger shape and do not change this conclusion.)

## Commands and exit codes
- bash $WORKSPACE/thunderstone/scripts/tests/health-test.sh: exit 0, passed=41 failed=0 (final run after shellcheck fixes)
- cd $WORKSPACE/thunderstone-starter: bash scripts/doctor.sh exit 0; npm test exit 0 ("Hygiene check passed", "Infrastructure validation passed"); npm run lint exit 0
- shellcheck health.sh exit 0, startup.sh exit 0, tests/health-test.sh exit 0 (two SC2209 and one SC2115 warnings fixed, then clean)
- bash -n health.sh / startup.sh: ok
- jq -e . ~/.cursor/hooks.json: before 0, after 0
- Hook command direct invocation: exit 0, 0.025 s
- `lean-ctx allow`: not run, no allowlist changes. One `base64` pipeline was blocked by the allowlist and abandoned (used WebFetch instead). Shell output was read raw with `LEAN_CTX_RAW=1` (env var only).
- `agent` usage: `agent --help` once; `agent status` ran inside health.sh during the real hook verification (login check, sends no model prompt). `agent` was not run for work and scripts/run-task.sh was not run.
- Reference pattern read-only via WebFetch (raw GitHub URL for .cursor/hooks.json.example) and the local $WORKSPACE/modme-ui-01 copy.

## Unverified / notes
- Live Cursor session behaviour of the hook (see Task 2).
- Usage-limit flag creation is tested with fake agents and `--scan-agent-output`; the real `agent status` has never shown limit wording, so in practice the flag will be created by `--scan-agent-output` piped from a real run.
- health-last.json reports git_modme=32135 changed paths in $WORKSPACE/modme-ui-01 (informational, pre-existing, not a failure).
- Commit/push/PR: not performed.
