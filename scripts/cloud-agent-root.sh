#!/usr/bin/env bash
# Resolve thunderstone-starter root for Cursor Cloud build pods (/workspace)
# and agent runtime (/agent/repos/thunderstone-starter).
set -euo pipefail

cloud_agent_repo_root() {
  local d
  for d in /workspace /agent/repos/thunderstone-starter; do
    if [[ -f "$d/scripts/bootstrap.sh" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cloud_agent_repo_root || {
    echo "Error: thunderstone-starter repo root not found." >&2
    echo "  Checked: /workspace and /agent/repos/thunderstone-starter (scripts/bootstrap.sh)" >&2
    echo "  Example: SKIP_CURSOR_INSTALL=1 sh /workspace/scripts/bootstrap.sh" >&2
    exit 1
  }
fi
