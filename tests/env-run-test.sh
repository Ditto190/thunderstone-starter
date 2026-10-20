#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/repo/scripts" "$TMP/elsewhere"
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/env-run.mjs" "$TMP/repo/scripts/env-run.mjs"
printf '%s\n' 'FROM_REPO=repo-env' >"$TMP/repo/.env.defaults"
(
  cd "$TMP/elsewhere"
  node "$TMP/repo/scripts/env-run.mjs" node -e 'if (process.env.FROM_REPO !== "repo-env") process.exit(1)'
)
echo "env-run-test passed"
