#!/usr/bin/env bash
# Re-vendor .agents/skills/composio from ComposioHQ/composio at an explicit commit SHA.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
COMMIT="${1:-}"
if [ -z "$COMMIT" ]; then
  echo "Usage: $0 <commit-sha>" >&2
  exit 2
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --filter=blob:none --no-checkout https://github.com/ComposioHQ/composio.git "$TMP"
git -C "$TMP" checkout "$COMMIT" -- skills/composio
rm -rf config/skills/vendored/composio
mkdir -p config/skills/vendored
cp -r "$TMP/skills/composio" config/skills/vendored/
node -e "
const fs=require('fs');
const p='config/skills/vendored/composio/PROVENANCE.json';
const j=JSON.parse(fs.readFileSync(p,'utf8'));
j.commit=process.argv[1];
j.vendoredAt=new Date().toISOString().slice(0,10);
fs.writeFileSync(p, JSON.stringify(j,null,2)+'\n');
" "$COMMIT"
echo "Updated composio skill at $COMMIT"
