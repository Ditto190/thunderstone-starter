#!/usr/bin/env bash
# Fails on absolute local paths, personal email addresses and common secret patterns
# in tracked files. Never prints matched secret values, only file:line and a rule name.
set -euo pipefail
root="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/hygiene-rules.sh"
cd "$root"

fail=0

while IFS= read -r -d '' file; do
  [ "$file" = "scripts/hygiene-rules.sh" ] && continue
  [ -f "$file" ] || continue
  grep -Iq . "$file" 2>/dev/null || continue
  while read -r lineno name; do
    [ -n "${lineno:-}" ] || continue
    echo "hygiene: $file:$lineno [$name]"
    fail=1
  done < <(hygiene_scan_file "$file")
done < <(git ls-files -z)

# Commit identities: every non-merge commit reachable from HEAD must be authored by the public alias
# (or GitHub's web-flow committer). HEAD is the branch under test and includes its main history.
# Do not use --all: actions/checkout fetch-depth 0 fetches refs/heads/*, and an unrelated remote
# branch is not part of this history. Do not exempt any author by name.
alias_name="Ditto190"
while IFS='|' read -r sha an ae cn ce subj; do
  # GitHub's synthetic PR merge commit uses the profile display name. Skip it only when its SHA is the
  # one Actions checked out (GITHUB_SHA), so a look-alike commit elsewhere in history can't bypass the check.
  if [ -n "${GITHUB_SHA:-}" ] && [ "$sha" = "$GITHUB_SHA" ] && [ "$cn" = "GitHub" ] \
     && printf '%s' "$subj" | grep -Eq '^Merge [0-9a-f]{40} into [0-9a-f]{40}$'; then continue; fi
  ok_author=0; ok_committer=0
  if [ "$an" = "$alias_name" ] && printf '%s' "$ae" | grep -Eq "^([0-9]+\\+)?Ditto190@users\\.noreply\\.github\\.com$"; then ok_author=1; fi
  if { [ "$cn" = "$alias_name" ] && printf '%s' "$ce" | grep -Eq "^([0-9]+\\+)?Ditto190@users\\.noreply\\.github\\.com$"; } \
     || { [ "$cn" = "GitHub" ] && [ "$ce" = "noreply@github.com" ]; }; then ok_committer=1; fi
  if [ "$ok_author" -ne 1 ] || [ "$ok_committer" -ne 1 ]; then
    echo "hygiene: commit ${sha:0:7} [non-alias author/committer identity]"
    fail=1
  fi
done < <(git log HEAD --format='%H|%an|%ae|%cn|%ce|%s' 2>/dev/null || true)

if [ "$fail" -ne 0 ]; then
  echo "Hygiene check failed. Use relative paths and keep secrets in untracked .env files." >&2
  exit 1
fi
echo "Hygiene check passed."
