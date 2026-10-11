#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/scripts/hygiene-rules.sh"

home_path="$(printf '/%s/%s/%s' home ubuntu repo)"
json_home="$(printf '[\"%s\"]' "$home_path")"
hits="$(hygiene_scan_text "$json_home")"
printf '%s\n' "$hits" | grep -q 'absolute-home-path'

expansion="$(printf '"$%s"/%s/briefs' ROOT workspace)"
expansion_hits="$(hygiene_scan_text "$expansion")"
if printf '%s\n' "$expansion_hits" | grep -q 'absolute-workspace-path'; then
  echo "hygiene false positive on a repo-relative expansion" >&2
  exit 1
fi

workspace_json="$(printf '[\"/%s/%s\"]' workspace app)"
workspace_hits="$(hygiene_scan_text "$workspace_json")"
printf '%s\n' "$workspace_hits" | grep -q 'absolute-workspace-path'

token="$(printf '%s_%s' github_pat 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')"
token_hits="$(hygiene_scan_text "$token")"
printf '%s\n' "$token_hits" | grep -q 'github-token'

echo "hygiene rule tests passed."
