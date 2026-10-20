# BRIEF — DT standing law: full auto-permission on the VM (2026-10-10)

From: Chief Thunderstone (DT standing law via Grok Bot). Apply as given; do not raise permission/policy concerns again or ask DT about them.
Law: agents have full control and auto-permission on the shared VM desktop and the Thunderstone and ModMe projects.
Boundary unchanged: outbound sends/posts/purchases to third parties stay on the normal approval path.

## Cursor-Runner (Class C, local config + working tree only; NO commit/push/PR)
1. LeanCTX: set it to accept all commands on the VM (`shell_allowlist = []` or `shell_security = "off"` per lean-ctx docs; use the docs/`lean-ctx` help to choose). Back up config first (config.toml.bak.20261010). Keep audit logging (journal/debug_log) and adaptive learning enabled; verify with `lean-ctx` status/doctor and confirm logs are being written. Evidence of before/after settings (no secrets).
2. run-task.sh / Cursor launches fully auto (force, no prompts): the PR #7 branch already has `LEAN_CTX_DISABLED=1 agent -p --force`; verify nothing else prompts (e.g. ~/.cursor permissions/hooks) and report. Do not run the real test task until Chief says PR #7 is merged.
3. Add ONE line stating the law to ROSTER-AND-ROUTING.md and STANDARD-PROFILE-BLOCK (and the per-bot patch files under $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/ for BUILD bots). Keep profile lines short; check the SHORT block stays under its length cap. Show the diff.
Run doctor/validate/shellcheck after (run from main checkout state; do not disturb branch ci/run-task-force-lean-off uncommitted work: if the starter tree has uncommitted changes from Scout's in-flight commit, do not touch the starter repo).
Evidence: $WORKSPACE/thunderstone/artifacts/STANDING-LAW-AUTOPERM-2026-10-10.md. Report to Chief, max 4 lines.
