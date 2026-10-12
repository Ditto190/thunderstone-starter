#!/usr/bin/env bash
# Vendor skills/composio from ComposioHQ/composio at an explicit commit.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

sha="${1:-}"
if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "usage: scripts/update-composio-skill.sh <40-hex-commit>" >&2
  exit 1
fi

files=(
  SKILL.md
  references/errors.md
  references/for-you.md
  references/platform.md
)
dest=".agents/skills/composio"
base="https://raw.githubusercontent.com/ComposioHQ/composio/${sha}/skills/composio"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for rel in "${files[@]}"; do
  mkdir -p "${work}/$(dirname -- "$rel")"
  curl --proto '=https' --tlsv1.2 -fsSL "${base}/${rel}" -o "${work}/${rel}"
done

rm -rf "$dest"
mkdir -p "$dest"
cp -a "${work}/." "$dest/"

files_json='[]'
for rel in "${files[@]}"; do
  hash="$(sha256sum "${dest}/${rel}" | awk '{print $1}')"
  files_json="$(jq -n \
    --argjson arr "$files_json" \
    --arg path "$rel" \
    --arg upstream "skills/composio/${rel}" \
    --arg sha256 "$hash" \
    '$arr + [{path:$path, upstreamPath:$upstream, sha256:$sha256}]')"
done

jq -n \
  --arg upstreamRepo "ComposioHQ/composio" \
  --arg commit "$sha" \
  --argjson files "$files_json" \
  '{upstreamRepo:$upstreamRepo, commit:$commit, files:$files}' \
  >"${dest}/PROVENANCE.json"

echo "Vendored Composio skill at ${sha}"
