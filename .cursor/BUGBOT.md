# Review rules for thunderstone-starter

Public repo. Be brief; report only real problems, one comment per issue.

## Blocking
- Secrets: any API key, token, private key, or `.env` value committed. Only names go in `.env.example`.
- Absolute local paths (home directories, workspace roots, Windows drive paths). Use relative paths.
- Personal data: real names or personal emails. Authors must be `Ditto190 <Ditto190@users.noreply.github.com>`.
- Workflow changes that use unpinned actions (not a full commit SHA), broaden `permissions`, or use `pull_request_target`.
- Behaviour changes in `scripts/` with no matching update or addition in `scripts/validate.sh` tests.
- Hooks or checks bypassed or weakened (`--no-verify`, removed hygiene or gitleaks steps).

## Non-blocking
- Shell quoting issues, missing `set -euo pipefail`, shellcheck warnings.
- Docs out of sync with changed scripts.

## Ignore
- Formatting, lockfiles, `manifest.sha256`, generated or `.state/` content.
