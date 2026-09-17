#!/usr/bin/env bash
set -euo pipefail
[[ "${ALLOW_LOCAL_COMMITS:-0}" = 1 ]] || { echo "Set ALLOW_LOCAL_COMMITS=1 to opt in."; exit 1; }
message="${1:?Provide commit message}"; shift
[[ "$#" -gt 0 ]] || { echo "Specify individual file paths"; exit 1; }
branch="$(git symbolic-ref --short HEAD)"
[[ "$branch" != main && "$branch" != master ]] || { echo "Use a task branch"; exit 1; }
git diff --cached --quiet || { echo "Existing staged changes: review first"; exit 1; }
for file in "$@"; do
  [[ -f "$file" && ! -L "$file" ]] || { echo "Only regular individual files accepted"; exit 1; }
  case "$file" in *'*'*|*'['*|*'?'*|*.pem|*.key|*.env|*.env.local|*/.env.*|.env.*|*credentials*|*rclone.conf*) echo "Sensitive or ambiguous path refused"; exit 1;; esac
done
npm test
git --literal-pathspecs add -- "$@"
git diff --cached --check
git commit -m "$message"
