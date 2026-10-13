#!/usr/bin/env bash
# Proves commit-identity rules without touching this repo's history.
set -euo pipefail

# Git hooks export GIT_DIR. Leaving it set makes `git init` rewrite the
# caller's repository instead of the fixture.
unset GIT_DIR GIT_WORK_TREE

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

new_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  mkdir -p "$repo/scripts"
  cp "$ROOT/scripts/check-hygiene.sh" "$repo/scripts/check-hygiene.sh"
  git -C "$repo" add scripts/check-hygiene.sh
  commit_as "$repo" "Ditto190" "Ditto190@users.noreply.github.com" \
    "Ditto190" "Ditto190@users.noreply.github.com" "base"
}

expect_pass() {
  local name="$1" repo="$2"
  if (cd "$repo" && bash scripts/check-hygiene.sh >/dev/null); then
    echo "hygiene-identity PASS: $name"
  else
    echo "hygiene-identity FAIL: $name (expected pass)" >&2
    failures=1
  fi
}

expect_fail() {
  local name="$1" repo="$2"
  if (cd "$repo" && bash scripts/check-hygiene.sh >/dev/null); then
    echo "hygiene-identity FAIL: $name (expected rejection)" >&2
    failures=1
  else
    echo "hygiene-identity PASS: $name"
  fi
}

alias_repo="$TMP_BASE/alias"
new_repo "$alias_repo"
expect_pass "public alias" "$alias_repo"

human_repo="$TMP_BASE/human"
new_repo "$human_repo"
commit_as "$human_repo" "Someone" "someone@example.com" \
  "Someone" "someone@example.com" "human commit"
expect_fail "non-alias human" "$human_repo"

github_committer_email="$(printf '%s@%s' 'noreply' 'github.com')"
dependabot_repo="$TMP_BASE/dependabot"
new_repo "$dependabot_repo"
commit_as "$dependabot_repo" "dependabot[bot]" \
  "49699333+dependabot[bot]@users.noreply.github.com" \
  "GitHub" "$github_committer_email" "chore: bump actions"
expect_pass "dependabot author with GitHub committer" "$dependabot_repo"

app_repo="$TMP_BASE/app"
new_repo "$app_repo"
commit_as "$app_repo" "coderabbitai[bot]" \
  "136622811+coderabbitai[bot]@users.noreply.github.com" \
  "coderabbitai[bot]" "136622811+coderabbitai[bot]@users.noreply.github.com" \
  "fix: review suggestion"
expect_pass "GitHub App author and committer" "$app_repo"

spoof_repo="$TMP_BASE/spoof"
new_repo "$spoof_repo"
commit_as "$spoof_repo" "dependabot[bot]" "dependabot@example.com" \
  "dependabot[bot]" "dependabot@example.com" "spoofed bot name"
expect_fail "bot name without noreply address" "$spoof_repo"

if [ "$failures" -ne 0 ]; then
  echo "Hygiene identity tests failed." >&2
  exit 1
fi
echo "Hygiene identity tests passed."
