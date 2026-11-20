# Task completion
- For infrastructure/config changes, run `npm test` (includes validation, ShellCheck, and hygiene); optionally run `npm run format:check`.
- For shell-only changes, also run targeted relevant test under `tests/` where available.
- Inspect `git diff --check` and preserve unrelated user changes.
- Before promotion, ensure no secrets/PII/absolute paths are introduced; commits/pushes/PRs require their own authorized workflow.