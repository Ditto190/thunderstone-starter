#!/usr/bin/env bash
# Create or update the repo label set (idempotent). Needs an authenticated gh CLI.
set -euo pipefail
repo="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
while IFS='|' read -r name color desc; do
  gh label create "$name" --color "$color" --description "$desc" --repo "$repo" --force >/dev/null
  echo "label: $name"
done < <(node "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/clan.mjs" labels)
