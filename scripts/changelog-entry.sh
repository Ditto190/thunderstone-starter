#!/usr/bin/env bash
# Render one Keep a Changelog bullet from merged-PR JSON (gh pr view --json number,title,labels,files,commits).
# usage: changelog-entry.sh --from-json <file|-> | changelog-entry.sh <pr-number>
set -euo pipefail
src="${1:-}"
case "$src" in
  --from-json) data="$(cat "${2:--}")" ;;
  ''|-*) echo "usage: $0 --from-json <file|-> | <pr-number>" >&2; exit 2 ;;
  *) data="$(gh pr view "$src" --json number,title,labels,files,commits)" ;;
esac
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
sections="$(node "$root/scripts/clan.mjs" labels --changelog)"
printf '%s' "$data" | jq -r --argjson sections "$sections" '
  def section:
    ((.labels // []) | map(.name)) as $names
    | (($sections | map(select(.label as $label | $names | index($label))) | .[0].section) // "Added");
  (.files // []) as $f
  | (.commits // []) as $c
  | "\(section)\t- \(.title) (#\(.number))"
    + (if ((.labels // []) | length) > 0 then " [" + ((.labels | map(.name)) | join(", ")) + "]" else "" end)
    + "\n  - files (\($f | length)): " + (($f | map(.path))[0:8] | join(", ")) + (if ($f | length) > 8 then ", ..." else "" end)
    + "\n  - commits (\($c | length)): " + (($c | map(.messageHeadline))[0:6] | join("; ")) + (if ($c | length) > 6 then "; ..." else "" end)'
