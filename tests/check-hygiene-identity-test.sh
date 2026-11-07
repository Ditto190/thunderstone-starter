#!/usr/bin/env bash
# Identity cases for scripts/check-hygiene.sh. The checker always inspects the
# repo that contains it, so each case is a temp repo with a copy of the script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

failures=0

commit_as() {
  local repo="$1" an="$2" ae="$3" cn="$4" ce="$5" msg="$6"
  GIT_AUTHOR_NAME="$an" GIT_AUTHOR_EMAIL="$ae" \
    GIT_COMMITTER_NAME="$cn" GIT_COMMITTER_EMAIL="$ce" \
    git -C "$repo" commit -q --allow-empty -m "$msg"
}

init_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  mkdir -p "$repo/scripts"
  cp "$ROOT/scripts/check-hygiene.sh" "$repo/scripts/check-hygiene.sh"
  git -C "$repo" config user.name "Ditto190"
  git -C "$repo" config user.email "Ditto190@users.noreply.github.com"
  commit_as "$repo" "Ditto190" "Ditto190@users.noreply.github.com" \
    "Ditto190" "Ditto190@users.noreply.github.com" "alias baseline"
}

expect_pass() {
  local name="$1" repo="$2" out status
  shift 2
  set +e
  out="$(bash "$repo/scripts/check-hygiene.sh" "$@" 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    echo "hygiene identity FAIL: $name (expected pass)" >&2
    echo "$out" >&2
    failures=1
  fi
}

expect_fail() {
  local name="$1" repo="$2" out status
  shift 2
  set +e
  out="$(bash "$repo/scripts/check-hygiene.sh" "$@" 2>&1)"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "hygiene identity FAIL: $name (expected rejection)" >&2
    failures=1
  fi
}

alias_repo="$TMP_BASE/alias"
init_repo "$alias_repo"
expect_pass "public alias" "$alias_repo"

dependabot_repo="$TMP_BASE/dependabot"
init_repo "$dependabot_repo"
github_committer_email="$(printf '%s@%s.%s' "noreply" "github" "com")"
commit_as "$dependabot_repo" \
  "dependabot[bot]" "49699333+dependabot[bot]@users.noreply.github.com" \
  "GitHub" "$github_committer_email" \
  "chore(deps): bump the actions group with 6 updates"
expect_pass "dependabot author with GitHub committer" "$dependabot_repo"

coderabbit_repo="$TMP_BASE/coderabbit"
init_repo "$coderabbit_repo"
commit_as "$coderabbit_repo" \
  "coderabbitai[bot]" "136622811+coderabbitai[bot]@users.noreply.github.com" \
  "coderabbitai[bot]" "136622811+coderabbitai[bot]@users.noreply.github.com" \
  "fix: review follow-up"
expect_pass "github app author and committer" "$coderabbit_repo"

spoof_repo="$TMP_BASE/spoof"
init_repo "$spoof_repo"
spoof_email="$(printf '%s@%s.%s' "dependabot" "personal" "example")"
commit_as "$spoof_repo" "dependabot[bot]" "$spoof_email" \
  "dependabot[bot]" "$spoof_email" "name only, not a github app address"
expect_fail "bot display name without github app email" "$spoof_repo"

personal_repo="$TMP_BASE/personal"
init_repo "$personal_repo"
personal_email="$(printf '%s@%s.%s' "person" "personal" "example")"
commit_as "$personal_repo" "Some Person" "$personal_email" \
  "Some Person" "$personal_email" "personal identity"
expect_fail "personal email identity" "$personal_repo"

actions_repo="$TMP_BASE/actions"
init_repo "$actions_repo"
actions_email="$(printf '%s+%s@%s.%s.%s' "41898282" "github-actions[bot]" "users" "noreply" "github.com")"
commit_as "$actions_repo" \
  "github-actions[bot]" "$actions_email" \
  "github-actions[bot]" "$actions_email" \
  "ci: workflow update"
expect_pass "github-actions app author and committer" "$actions_repo"

cursor_email="$(printf '%s@%s.%s' "cursoragent" "cursor" "com")"
cursor_repo="$TMP_BASE/cursor"
init_repo "$cursor_repo"
commit_as "$cursor_repo" "Cursor Agent" "$cursor_email" \
  "Cursor Agent" "$cursor_email" "cursor exact pair"
expect_pass "cursor agent exact pair" "$cursor_repo"

cursor_web_repo="$TMP_BASE/cursor-web"
init_repo "$cursor_web_repo"
commit_as "$cursor_web_repo" "Cursor Agent" "$cursor_email" \
  "GitHub" "$github_committer_email" "cursor author, github web-flow committer"
expect_pass "cursor agent with github committer" "$cursor_web_repo"

cursor_bad_mail_repo="$TMP_BASE/cursor-bad-mail"
init_repo "$cursor_bad_mail_repo"
other_cursor_email="$(printf '%s@%s.%s' "other" "cursor" "com")"
commit_as "$cursor_bad_mail_repo" "Cursor Agent" "$other_cursor_email" \
  "Cursor Agent" "$other_cursor_email" "cursor name, other email"
expect_fail "cursor name with other email" "$cursor_bad_mail_repo"

cursor_bad_name_repo="$TMP_BASE/cursor-bad-name"
init_repo "$cursor_bad_name_repo"
commit_as "$cursor_bad_name_repo" "Not Cursor" "$cursor_email" \
  "Not Cursor" "$cursor_email" "other name, cursor email"
expect_fail "other name with cursor email" "$cursor_bad_name_repo"

range_repo="$TMP_BASE/range"
init_repo "$range_repo"
commit_as "$range_repo" "Some Person" "$personal_email" \
  "Some Person" "$personal_email" "bad identity on main"
git -C "$range_repo" checkout -q -b feature
commit_as "$range_repo" "Ditto190" "Ditto190@users.noreply.github.com" \
  "Ditto190" "Ditto190@users.noreply.github.com" "alias on branch"
HYGIENE_RANGE="main..HEAD" expect_pass "range env skips main personal commit" "$range_repo"
expect_pass "positional range skips main personal commit" "$range_repo" "main..HEAD"
expect_fail "full HEAD includes personal commit on main" "$range_repo"

invalid_range_repo="$TMP_BASE/invalid-range"
init_repo "$invalid_range_repo"
HYGIENE_RANGE="nonexistent-ref..HEAD" expect_fail "invalid identity range" "$invalid_range_repo"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
echo "Hygiene identity tests passed."
