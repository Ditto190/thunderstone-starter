#!/usr/bin/env bash
# Fails on absolute local paths, personal email addresses and common secret patterns
# in tracked files. Never prints matched secret values, only file:line and a rule name.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

self="scripts/check-hygiene.sh"
fail=0

# rule name | ERE pattern
rules=(
  "absolute-home-path|(^|[[:space:]=(:\`]|[[:space:]=(][\"'])/(home|Users|root)/[A-Za-z0-9_.-]+"
  "absolute-workspace-path|(^|[[:space:]=(:\`]|[[:space:]=(][\"'])/workspace(/|[[:space:]\"'\`]|$)"
  "windows-drive-path|(^|[^A-Za-z])[A-Za-z]:\\\\[A-Za-z0-9_.-]"
  "local-project-dir|Github_Projects"
  "email-address|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}"
  "private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----"
  "github-token|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}"
  "generic-api-key|(sk|xai|crsr|key)[-_][A-Za-z0-9_-]{20,}"
  "aws-access-key|AKIA[0-9A-Z]{16}"
  "google-api-key|AIza[0-9A-Za-z_-]{35}"
  "slack-token|xox[baprs]-[A-Za-z0-9-]{10,}"
  "credential-assignment|(api[_-]?key|secret|token|passw(or)?d)[A-Za-z_]*[[:space:]]*[=:][[:space:]]*[\"']?[A-Za-z0-9/+_-]{20,}"
)

# Allowed email domains (placeholders and GitHub noreply addresses)
email_allow='@(users\.noreply\.github\.com|noreply\.github\.com|example\.(com|org|net))$'

while IFS= read -r -d '' file; do
  [ "$file" = "$self" ] && continue
  [ -f "$file" ] || continue
  grep -Iq . "$file" 2>/dev/null || continue
  for rule in "${rules[@]}"; do
    name="${rule%%|*}"
    pattern="${rule#*|}"
    while IFS=: read -r lineno match; do
      [ -n "$lineno" ] || continue
      if [ "$name" = "email-address" ] && printf '%s' "$match" | grep -Eq "$email_allow"; then
        continue
      fi
      echo "hygiene: $file:$lineno [$name]"
      fail=1
    done < <(grep -nEoi -e "$pattern" -- "$file" || true)
  done
done < <(git ls-files -z)

# Commit identities: only exact known bot name+email pairs or GitHub App noreply addresses.
# Do not use --all: actions/checkout fetch-depth 0 fetches refs/heads/*, and an unrelated remote
# branch is not part of this history.
# GitHub Apps (Dependabot, CodeRabbit, github-actions) commit as
# <id>+<app>[bot]@users.noreply.github.com. Accept that GitHub-assigned address only;
# a display name ending in [bot] is not enough on its own.
# Cursor Agent is allowed only as the exact name "Cursor Agent" with cursoragent@cursor.com.
# Its committer may be that same pair or GitHub's web-flow committer.
alias_name="Ditto190"
bot_email='^[0-9]+\+[^@[:space:]]+\[bot\]@users\.noreply\.github\.com$'
cursor_name="Cursor Agent"
cursor_email="cursoragent@cursor.com"

# Range: arg, else HYGIENE_RANGE, else origin/$GITHUB_BASE_REF..HEAD, else origin/main..HEAD,
# else HEAD (local repos with no remote, including the identity tests).
identity_range="${1:-${HYGIENE_RANGE:-}}"
if [ -z "$identity_range" ]; then
  if [ -n "${GITHUB_BASE_REF:-}" ] && git rev-parse --verify --quiet "origin/${GITHUB_BASE_REF}" >/dev/null; then
    identity_range="origin/${GITHUB_BASE_REF}..HEAD"
  elif git rev-parse --verify --quiet origin/main >/dev/null; then
    identity_range="origin/main..HEAD"
  else
    identity_range="HEAD"
  fi
fi
echo "hygiene: identity range ${identity_range}"
log_args=("$identity_range")
if [ "$identity_range" != "HEAD" ]; then
  if ! range_count="$(git rev-list --count "$identity_range" 2>/dev/null)"; then
    echo "hygiene: invalid identity range" >&2
    exit 1
  fi
  if [ "$range_count" = "0" ]; then
    log_args=(-1 HEAD)
  fi
fi

while IFS='|' read -r sha an ae cn ce subj; do
  # GitHub's synthetic PR merge commit uses the profile display name. Skip it only when its SHA is the
  # one Actions checked out (GITHUB_SHA), so a look-alike commit elsewhere in history can't bypass the check.
  if [ -n "${GITHUB_SHA:-}" ] && [ "$sha" = "$GITHUB_SHA" ] && [ "$cn" = "GitHub" ] \
     && printf '%s' "$subj" | grep -Eq '^Merge [0-9a-f]{40} into [0-9a-f]{40}$'; then continue; fi
  ok_author=0; ok_committer=0
  if [ "$an" = "$alias_name" ] && printf '%s' "$ae" | grep -Eq "^([0-9]+\\+)?Ditto190@users\\.noreply\\.github\\.com$"; then ok_author=1; fi
  if printf '%s' "$ae" | grep -Eq "$bot_email"; then ok_author=1; fi
  if [ "$an" = "$cursor_name" ] && [ "$ae" = "$cursor_email" ]; then ok_author=1; fi
  if { [ "$cn" = "$alias_name" ] && printf '%s' "$ce" | grep -Eq "^([0-9]+\\+)?Ditto190@users\\.noreply\\.github\\.com$"; } \
     || { [ "$cn" = "GitHub" ] && [ "$ce" = "noreply@github.com" ]; } \
     || { [ "$cn" = "$cursor_name" ] && [ "$ce" = "$cursor_email" ]; } \
     || printf '%s' "$ce" | grep -Eq "$bot_email"; then ok_committer=1; fi
  if [ "$ok_author" -ne 1 ] || [ "$ok_committer" -ne 1 ]; then
    echo "hygiene: commit ${sha:0:7} [non-alias author/committer identity]"
    fail=1
  fi
done < <(git log "${log_args[@]}" --format='%H|%an|%ae|%cn|%ce|%s' 2>/dev/null || true)

if [ "$fail" -ne 0 ]; then
  echo "Hygiene check failed. Use relative paths and keep secrets in untracked .env files." >&2
  exit 1
fi
echo "Hygiene check passed."
