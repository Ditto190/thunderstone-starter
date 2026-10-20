#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export CLAN_ENTRY=export-drive
exec node "$root/scripts/env-run.mjs" node "$root/scripts/clan.mjs" export "$@"
