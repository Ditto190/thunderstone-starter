#!/usr/bin/env bash
# Dev Container / Codespaces post-create: deps + doctor (no Cursor CLI install).
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
export SKIP_CURSOR_INSTALL="${SKIP_CURSOR_INSTALL:-1}"
export PATH="${HOME}/.local/bin:${PATH}"

if command -v node >/dev/null 2>&1; then
  node -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)'
else
  echo "post-create: node >= 22 required" >&2
  exit 1
fi

npm ci --no-audit --no-fund
bash scripts/doctor.sh || true
echo "post-create: ready. See docs/dev-stack/LOCAL-DEV.md (VM remains primary for My Machines / Computer Use)."