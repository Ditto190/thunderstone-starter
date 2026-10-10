#!/usr/bin/env bash
# Append a merged PR to the draft "Unreleased" GitHub release (no commits to main).
# usage: release-notes-append.sh <pr-number>   (needs gh auth with contents: write)
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
pr="${1:?pr number required}"
repo="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
entry="$(bash scripts/changelog-entry.sh "$pr" | cut -f2-)"
id="$(gh api "repos/$repo/releases" --paginate --jq '.[]|select(.draft and .name=="Unreleased")|.id' | head -1)"
if [ -z "$id" ]; then
  gh api -X POST "repos/$repo/releases" -f tag_name=unreleased -f name=Unreleased -F draft=true -f body="$entry" >/dev/null
  echo "created draft Unreleased with #$pr"
  exit 0
fi
body="$(gh api "repos/$repo/releases/$id" --jq .body)"
if printf '%s' "$body" | grep -qF "(#$pr)"; then echo "#$pr already listed"; exit 0; fi
gh api -X PATCH "repos/$repo/releases/$id" -f body="$body
$entry" >/dev/null
echo "appended #$pr to draft Unreleased"
