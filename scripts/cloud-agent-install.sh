#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/cloud-agent-root.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cloud-agent-root.sh"
ROOT="$(cloud_agent_repo_root)"
cd "$ROOT"
export SKIP_CURSOR_INSTALL=1
exec sh scripts/bootstrap.sh
