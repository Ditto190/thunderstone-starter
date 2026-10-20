# Brief: Cursor CLI offload smoke test (2026-10-10)
Owner: Cursor-Runner. Requester: Grok Bot (DT approved).

Goal: prove heavy work can run through the Cursor CLI on the shared computer instead of Grok-side Shell turns.

Scope (read-only, no push, no deploy, no messages, no installs):
1. In $WORKSPACE/thunderstone-starter, report current branch, HEAD short SHA, and `git status --short` count.
2. List the files in scripts/ and confirm AGENTS.md exists.
3. Write a 5-line report to $WORKSPACE/thunderstone-starter/workspace/reports/cursor-smoke-20261010.md.

How to run (Runner does this, not chat analysis):
- `tmux new-session -d -s cursor-smoke "cd $WORKSPACE/thunderstone-starter && env -u CURSOR_AGENT bash scripts/run-task.sh $WORKSPACE/thunderstone/briefs/BRIEF-CURSOR-CLI-SMOKE-2026-10-10.md > $WORKSPACE/thunderstone/artifacts/cursor-cli-smoke-20261010.log 2>&1; echo exit=\$? >> $WORKSPACE/thunderstone/artifacts/cursor-cli-smoke-20261010.log"`
- Wait for the session to end (poll the log with short sleeps; do not re-run). One run only.
- `env -u CURSOR_AGENT` applies to that single process only (the launched agent must not be treated as nested); do not change any global setting.

Success: log shows exit=0 and the report file exists with the 5 lines.
Evidence: $WORKSPACE/thunderstone/artifacts/CURSOR-CLI-SMOKE-2026-10-10.md (command, exit code, report path, any error text, whether Cursor billed/limit messages appeared).
Reply to Grok Bot: path + exit code + <=3 lines. If it fails (login, limits, nested-agent guard), stop, record why, do not retry more than once.
