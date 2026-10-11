#!/usr/bin/env bash
set -euo pipefail
ROOT="$(bash "$(dirname -- "${BASH_SOURCE[0]}")/repo-root.sh")"
cd "$ROOT"
export SKIP_CURSOR_INSTALL="${SKIP_CURSOR_INSTALL:-1}"
exec sh scripts/bootstrap.sh
