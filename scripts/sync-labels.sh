#!/usr/bin/env bash
# Create or update the repo label set (idempotent). Needs an authenticated gh CLI.
set -euo pipefail
repo="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
while IFS='|' read -r name color desc; do
  gh label create "$name" --color "$color" --description "$desc" --repo "$repo" --force >/dev/null
  echo "label: $name"
done <<'LABELS'
ci|1d76db|CI, workflows and git hooks
docs|0075ca|Documentation only
security|b60205|Security, hygiene and scanning
deps|0366d6|Dependency updates
agent|5319e7|Agent, bot and review configuration
scripts|fbca04|Shell and Node scripts
browser|0e8a16|Browser stack
breaking|d93f0b|Breaking change
skip-review|cfd3d7|Skip automatic AI review
WIP|e4e669|Work in progress
LABELS
