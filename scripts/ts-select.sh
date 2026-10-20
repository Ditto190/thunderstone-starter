#!/usr/bin/env bash
# ts-select.sh — thin ts-* wrapper around select.sh in this directory.
# Exit codes pass through: 0 hit, 1 NO_MATCH, 2 usage.
# No network unless --external is passed through to select.sh.
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo 'usage: ts-select.sh "<task>" [--kind k] [--top N] [--json] [--root DIR] [--external]' >&2
  exit 0
fi
exec bash "$D/select.sh" "$@"
