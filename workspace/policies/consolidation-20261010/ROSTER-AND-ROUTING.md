# Roster and routing (2026-10-10, DT decisions applied)

## Roster
| Bot | Role | Owns |
|---|---|---|
| Grok Bot (primary) | Single front door + router. Absorbs Chief of Staff | Intake, routing, strategy/priorities, decision escalation to DT, weekly digest |
| Chief Thunderstone | Sole VM execution lead. Absorbs CoS ops + Lorekeeper context duties (on demand) | Briefs, VM health, evidence, Class C/D gating |
| Cursor-Runner | Executor under Thunderstone | Runs briefs via Cursor CLI (`scripts/run-task.sh`) |
| Git-Scout | Git gate under Thunderstone | Review + approved git writes only |
| Chief Lorekeeper | ON-DEMAND knowledge worker, hidden, no routines | Drive wiki/index/context packs when briefed |
| Executive Assistant | Calendar/email/Drive-lookup | Google + M365 admin, drafts only |
| Engineering Lead | SWE Tribe lead (BUILD), under Thunderstone | Engineering loop; event-triggered, no cadence |
| SWE, Lingxi's Engineer Bot, Senior Developer, Projects Manager, Researcher | SWE Tribe members | Code/triage/PR review/prod issues; CI/CD and PR gates; architecture; codebase-side PM; research |
| Tradbot, dr eggbot, tinkabot | Specialists (see ROUTINE-AUDIT) | Own lane only |
| Nightly Audit Engineer | Replaced | `briefs/TEMPLATE-AUDIT-AREA.md` (one area per Runner brief) |
| Hidden: Chief of Staff, Chief Lorekeeper (surface on demand) | | |
| Delete candidates: "New Bot", "New Agent" (empty), Thunderstone Clan group if unused | | |

## Messaging (hub-and-spoke)
- DT <-> Grok Bot. Grok Bot <-> Thunderstone/EA/specialists. Thunderstone <-> Runner/Scout. Lorekeeper only via Grok Bot or Thunderstone.
- Message only if it needs action or carries a result. No acknowledgements, no FYIs, no "already covered".
- One owner per task. 1:1 only. No fan-out, no group @s, no relaying results back through a third bot: reports go to the requester as a file path + 3 lines.
- Silent when green.

## Tool order
project files > Context7 / xAI docs > GitHub > GitLab > Githits > Drive > Serena (code nav) > web > computer-use LAST (visual QA, UI-only auth, one-offs; state target/actions/stop first).

## Heavy work (Cursor CLI assumed available)
Anything beyond a 1-2 command check = brief file in $THUNDERSTONE_ROOT/briefs/ -> Runner runs `bash scripts/run-task.sh <brief>` (Cursor CLI `agent -p`) as a separate detached process inside a tmux session in $THUNDERSTONE_STARTER -> evidence in $THUNDERSTONE_ROOT/artifacts/ -> Runner replies path + exit code + <=5 lines. No multi-step investigation in chat. No bot does repo analysis itself.
Graceful fallback: if `agent` exits with a usage-limit error, STOP, record it in the artifact, and notify Grok Bot once. No retry loops. No silent Grok-side fallback for big jobs; DT decides (wait for reset, upgrade, or an explicit one-off exception).

## Compression stack (applies to all messaging and routine rules; no other rules assumed)
- LeanCTX: `lean-ctx read <file> -m map|signatures` for structure, `-m full --fresh` only when the implementation is needed; `lean-ctx -c "<cmd>"` for compressed shell output (`lean-ctx raw` is the escape hatch); adaptive learning is `auto_mode_learning = true` (inspect with `lean-ctx learning`; the docs mark learning as Research/opt-in). See evidence file for verified commands.
- Caveman: opt-in terse style for bot-to-bot messages only. Never applied to commands, paths, approvals or safety text, which are written in full.
- Serena MCP: symbol-level code reads and edits instead of whole-file reads.

## Gates (unchanged)
Standing law (DT, 2026-10-10): agents have full auto-permission on the VM desktop and the Thunderstone/ModMe projects; no permission concerns there. Boundary unchanged: third-party send/post/purchase and commit/push/delete stay on DT approval (Git-Scout for git writes).
Class D (commit/push/PR/merge/deploy/delete/purchase/send) = Git-Scout or explicit DT approval of exact action. No `git add -A`, no auto-push, no secrets in output. Code SoR = GitHub; knowledge SoR = Drive wiki. en-AU.

## Cursor availability (decided by DT, 2026-10-10)
- Assumed available: DT is buying the plan; the usage limit currently blocks runs until it resets or the plan is upgraded.
- Workspace trust persisted: `~/.cursor/projects/workspace-thunderstone-starter/.workspace-trusted` exists (created by the approved `--trust` smoke retry).
- `agent` and `tmux` are allowed in the lean-ctx shell allowlist. Bot shells still carry CURSOR_AGENT=1; launch the CLI only as a detached tmux process via `scripts/run-task.sh`, never inline.
- Weekday health: `bash $THUNDERSTONE_ROOT/scripts/startup.sh` (wraps `health.sh`) replaces the duplicate model routines; see ROUTINE-AUDIT.md.
