#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${THUNDERSTONE_REPO_ROOT:-}" && -f "${THUNDERSTONE_REPO_ROOT}/scripts/bootstrap.sh" ]]; then
  printf '%s\n' "$THUNDERSTONE_REPO_ROOT"
  exit 0
fi
if [[ -f /agent/repos/thunderstone-starter/scripts/bootstrap.sh ]]; then
  printf '%s\n' /agent/repos/thunderstone-starter
  exit 0
fi
cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
