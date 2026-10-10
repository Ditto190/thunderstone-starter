# Security Policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
**Security tab > Report a vulnerability** (private vulnerability reporting).
Do not open a public issue for security problems.

## Handling secrets

- Never commit credentials. Real values belong in untracked files (`.env.local`,
  `~/.config/thunderstone/env`) or injected environment variables.
- `.env.example` and `.env.defaults` must only hold empty or non-sensitive placeholders.
- Use relative paths only. Absolute local paths (home directories, drive letters) are rejected by
  `scripts/check-hygiene.sh`, which runs in CI and in the Husky pre-commit and pre-push hooks.
- If a secret is ever committed, revoke and rotate it first, then remove it from history.

## Automated protections

GitHub secret scanning with push protection, Dependabot, CodeQL, a gitleaks workflow, and a
repository ruleset on `main` (pull request and passing checks required, no force-push or deletion).
