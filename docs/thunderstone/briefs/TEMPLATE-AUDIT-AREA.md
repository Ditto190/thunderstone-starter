# TEMPLATE — audit one codebase area (replaces the Nightly Audit Engineer bot)
Copy to $WORKSPACE/thunderstone/briefs/BRIEF-AUDIT-<area>-<date>.md, fill the fields, send to Cursor-Runner via Chief Thunderstone. Class C. One area per run.

## Fill in
- Area: <directory/module/feature, e.g. scripts/ or docs/>
- Repo: <owner/repo and local path>
- Scope: <what to look for: bugs, dead code, flaky tests, docs drift, security hygiene, dependency risk; what is out of scope>
- Validation: <commands that must pass after any change, e.g. shellcheck, npm test, bash scripts/doctor.sh, git diff --check>
- Trigger: <the event that started this: DT request, Chief brief, CI failure, PR event. Never a cron or timer>

## How to run
1. Map first: `lean-ctx read <file> -m map|signatures`, or `rg`/`fd` for structure. No whole-file reads unless a change needs the detail.
2. Find at most 5 findings, ranked by impact. Cite file:line and the evidence command for each.
3. Propose ONE cleanup for the area. Code changes only on a new branch from main (own worktree), never on the main checkout or another PR's branch.
4. Run the Validation commands; record exit codes.

## Output
Evidence file $WORKSPACE/thunderstone/artifacts/AUDIT-<area>-<date>.md, then report to Chief: path + <=5 lines (findings count, change proposed, validation exits, branch name).

## Hard rules
- Git writes (stage, commit, push, PR) go through Git-Scout with DT's exact approval; DT merges. Runner does not commit or push.
- No secrets, tokens or personal data in files, logs or messages. Repo may be public: use relative paths.
- Third-party sends/posts/purchases need DT approval. en-AU.
- If the Cursor CLI hits a usage limit: stop, record it, tell Grok Bot once. No retry loops.

## Stop conditions
Stop and report instead of continuing when: the tree has unrelated dirt; validation fails twice for the same reason; the change would exceed the stated scope or touch >10 files; a secret appears; anything needs a decision from DT.
