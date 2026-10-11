#!/usr/bin/env bash
set -euo pipefail
ROOT="$(bash "$(dirname -- "${BASH_SOURCE[0]}")/repo-root.sh")"
cd "$ROOT"
exec bash scripts/resume.sh
