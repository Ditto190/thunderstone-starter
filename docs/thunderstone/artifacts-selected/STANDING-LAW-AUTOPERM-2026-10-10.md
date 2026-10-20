# STANDING-LAW-AUTOPERM — 2026-10-10
Worker: Cursor-Runner (Class C). Brief: $WORKSPACE/thunderstone/briefs/BRIEF-STANDING-LAW-AUTOPERM-2026-10-10.md
Local config + policy files only. Starter repo untouched (main @ 4429619, status empty before and after). No stage/commit/push.

## 1. LeanCTX config (backup ~/.config/lean-ctx/config.toml.bak.20261010)
Diff (only change):
```
24a25
> shell_allowlist = []
```
- `lean-ctx allow --list` -> "Mode: disabled (every command is allowed)". Previously blocked `dpkg` now runs.
- Kept on: journal_enabled=true, debug_log=true, auto_capture=true, tee_mode="always", auto_mode_learning=true.
- Logs writing (mtime = now, 19:44): ~/.local/share/lean-ctx/savings/ledger.jsonl, ~/.local/state/lean-ctx/events.jsonl, ~/.local/share/lean-ctx/metering.jsonl, tee/*.log.
- `lean-ctx doctor`: 38/38 checks passed; `lean-ctx status`: doctor 6/6, shadow_mode active.
- RESIDUAL: command-position `$(...)`/backticks/eval is still blocked ("regardless of allowlist"). That is the separate `shell_security` guard, not the allowlist. Not turned off (brief allowed allowlist=[] OR security off). Workaround in use: put logic in a script file and run `bash file`. Say if you want `shell_security = "off"` too.

## 2. Cursor / agent launches
- scripts/run-task.sh on PR #7 branch: `exec env LEAN_CTX_DISABLED=1 agent -p --force ...` (no prompts).
- ~/.cursor/cli-config.json: approvalMode="allowlist", sandbox.mode="disabled", permissions allow=13 (Shell ls/cat/grep/rg/head/echo/env/which/command/lean-ctx, Mcp lean-ctx), deny=0. Workspace trust persisted for the starter.
- Finding: INTERACTIVE `agent` (no --force) would still prompt for commands outside that allowlist. `agent -p --force` (run-task.sh) does not. Not changed (brief = verify and report). Option: set approvalMode to full-auto/run-everything in cli-config.json (needs your OK).
- ~/.cursor/hooks.json: preToolUse x4, sessionStart x2, preCompact x1 (lean-ctx + health --bg); none block or prompt.

## 3. Law line (one line) added; backups in $WORKSPACE/thunderstone/state/backups-autoperm-20261010/
Rule 7 now states: full auto-permission on the VM and Thunderstone/ModMe; DT approval still for third-party send/post/purchase and commit/push/delete (Git-Scout for git writes). I kept the commit/push/delete approval because the brief says the outbound boundary is unchanged and Git-Scout gating is mid-flow; tell me if DT wants that loosened.
Files: STANDARD-PROFILE-BLOCK.md (still 12 lines), ROSTER-AND-ROUTING.md (line under "Gates"), groups/STANDARD-PROFILE-BLOCK-SHORT.md (894/900 chars; compressed rules 1,2,4,10 wording, all 10 rules kept), BUILD patches: chief-thunderstone 1584, cursor-runner 1555, git-scout 1598, senior-developer 1543, lingxis-engineer-bot 1346, nightly-audit-engineer 1321, swe 1370 (all <=1600). Non-BUILD patches not changed.
Diff vs backups:
```
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/ROSTER-AND-ROUTING.md	2026-10-10 19:45:29.751076828 +1100
+Standing law (DT, 2026-10-10): agents have full auto-permission on the VM desktop and the Thunderstone/ModMe projects; no permission concerns there. Boundary unchanged: third-party send/post/purchase and commit/push/delete stay o
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/STANDARD-PROFILE-BLOCK.md	2026-10-10 19:45:29.751076828 +1100
-7. Never send/post/commit/push/delete/purchase without DT's exact approval. No secret values. en-AU.
+7. Law (DT 2026-10-10): full auto-permission on the VM desktop and the Thunderstone/ModMe projects; no permission concerns there. DT's exact approval still needed for third-party send/post/purchase and for commit/push/delete (via
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/STANDARD-PROFILE-BLOCK-SHORT.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/chief-thunderstone.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/cursor-runner.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/git-scout.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/lingxis-engineer-bot.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/nightly-audit-engineer.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/senior-developer.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+++ $WORKSPACE/thunderstone/policies/consolidation-20261010/groups/swe.patch.md	2026-10-10 19:45:49.083076828 +1100
-1 Hub-and-spoke: 1:1 with requester; no fan-out/group @s.
-2 Message only for action or result; no acks/FYIs; silent when green.
+1 Hub-and-spoke: 1:1 with requester; no fan-out/@s.
+2 Message only for action/result; no acks; silent when green.
-4 Heavy work (repo reads, code, tests, multi-step CLI): brief file to Cursor-Runner via Chief Thunderstone (Cursor CLI, scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
+4 Heavy work (repo, code, tests, CLI): brief to Cursor-Runner via Chief (scripts/run-task.sh). Usage limit: stop, record, tell Grok Bot once; no retries.
-7 No send/post/commit/push/delete/buy without DT's exact approval; no secrets; en-AU.
+7 Law (DT 10-10): full auto-permission on VM + Thunderstone/ModMe; DT approval: third-party send/post/purchase, commit/push/delete; no secrets; en-AU.
-10 First work turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
+10 First turn: bash $WORKSPACE/thunderstone/scripts/health.sh --bg once; no wait.
```

## 4. Checks (read-only, from main checkout)
doctor.sh 0 | npm test 0 | shellcheck scripts/*.sh 0 | git diff --check 0
Commit/push/PR: not performed.

## 5. Follow-up approved by Chief (standing law) — 2026-10-10 19:5x AEDT
Cursor CLI docs: https://cursor.com/docs/cli/reference/configuration (approvalMode = allowlist | auto-review | unrestricted).
| Setting | Before | After | Backup |
|---|---|---|---|
| ~/.cursor/cli-config.json approvalMode | "allowlist" | "unrestricted" | ~/.cursor/cli-config.json.bak.20261010 (mode 600; contains login info, not printed) |
| ~/.config/lean-ctx/config.toml shell_security | unset (default guard on) | "off" | ~/.config/lean-ctx/config.toml.bak2.20261010 |

Only those two lines changed (permissions.allow list, sandbox.mode=disabled untouched).
Verified: `$(...)` at command position now runs in the Shell tool; lean-ctx allow --list "disabled (every command is allowed)"; journal_enabled, debug_log, auto_capture, tee_mode, auto_mode_learning still true; `lean-ctx doctor` 37/37 passed (was 38/38 before shell_security off; the count drop is one fewer check, no failures).
Caveat: unrestricted auto-approves everything for interactive `agent` (shell, MCP, fetch, file writes) with no classifier. Revert: copy the .bak files back.
README edit separately: $WORKSPACE/thunderstone/artifacts/README-FORCE-FIX-2026-10-10.md. Commit/push/PR: not performed.
