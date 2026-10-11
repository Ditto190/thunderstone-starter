#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$root/.state"
exec 9>"$root/.state/run.lock"
flock -n 9 || { echo "Another run holds this checkout. Use a separate worktree." >&2; exit 1; }
export CLAN_ENTRY=run-task
exec node "$root/scripts/env-run.mjs" node "$root/scripts/clan.mjs" run "$@"
