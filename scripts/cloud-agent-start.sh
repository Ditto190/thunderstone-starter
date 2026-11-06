#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/cloud-agent-root.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cloud-agent-root.sh"
ROOT="$(cloud_agent_repo_root)"
cd "$ROOT"
exec bash scripts/resume.sh
