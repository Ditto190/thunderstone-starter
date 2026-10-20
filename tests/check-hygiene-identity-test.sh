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
  set +e
  out="$(bash "$repo/scripts/check-hygiene.sh" 2>&1)"
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
  set +e
  out="$(bash "$repo/scripts/check-hygiene.sh" 2>&1)"
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

web_merge_repo="$TMP_BASE/web-merge"
init_repo "$web_merge_repo"
base_sha="$(git -C "$web_merge_repo" rev-parse HEAD)"
into_sha="$(git -C "$web_merge_repo" rev-parse 'HEAD^{tree}')"
merge_subject="Merge ${base_sha} into ${into_sha}"
merge_author_email="$(printf '%s@%s.%s' "merger" "personal" "example")"
commit_as "$web_merge_repo" "Web Merger" "$merge_author_email" \
  "GitHub" "$github_committer_email" "$merge_subject"
merge_sha="$(git -C "$web_merge_repo" rev-parse HEAD)"
GITHUB_EVENT_NAME=pull_request GITHUB_SHA="$merge_sha" \
  expect_pass "pull request web merge" "$web_merge_repo"
GITHUB_EVENT_NAME=push GITHUB_SHA="$merge_sha" \
  expect_fail "push event does not skip web merge" "$web_merge_repo"

other_merge_repo="$TMP_BASE/other-merge"
init_repo "$other_merge_repo"
other_email="$(printf '%s@%s.%s' "merge" "personal" "example")"
commit_as "$other_merge_repo" "Ditto190" "Ditto190@users.noreply.github.com" \
  "GitHub" "$other_email" "$merge_subject"
other_sha="$(git -C "$other_merge_repo" rev-parse HEAD)"
GITHUB_EVENT_NAME=pull_request GITHUB_SHA="$other_sha" \
  expect_fail "web merge subject with another committer email" "$other_merge_repo"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
echo "Hygiene identity tests passed."
