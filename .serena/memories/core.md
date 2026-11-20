# Core
- VM/agent starter, not an application; infrastructure validation is the test scope until adopted by an app.
- Root instructions: `AGENTS.md`; preserve Drive-first source of truth and GitHub promotion boundary.
- Agent topology is sequential investigator -> implementer -> verifier; one writer/task, worktree for concurrent writers; never recursively invoke agents.
- Environment is loaded only through `scripts/env-run.mjs`; secrets stay in injected env or local secret files, never commits.
- See `mem:tech_stack` for runtime and `mem:suggested_commands` for safe operational commands.