#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${ROOT}/.agents/skills/composio"
failures=0

fail() {
  echo "composio test FAIL: $*" >&2
  failures=1
}

if git -C "$ROOT" check-ignore -q -- .agents/skills/composio/SKILL.md; then
  fail "composio skill is gitignored"
fi

for rel in SKILL.md references/errors.md references/for-you.md references/platform.md PROVENANCE.json; do
  if [ ! -f "${SKILL}/${rel}" ]; then
    fail "missing ${rel}"
  fi
done

commit="$(jq -r '.commit' "${SKILL}/PROVENANCE.json")"
if ! printf '%s' "$commit" | grep -Eq '^[0-9a-f]{40}$'; then
  fail "provenance commit is not 40 hex"
fi
if [ "$(jq -r '.upstreamRepo' "${SKILL}/PROVENANCE.json")" != "ComposioHQ/composio" ]; then
  fail "unexpected upstream repo"
fi

while IFS= read -r row; do
  path="$(jq -r '.path' <<<"$row")"
  want="$(jq -r '.sha256' <<<"$row")"
  got="$(sha256sum "${SKILL}/${path}" | awk '{print $1}')"
  if [ "$want" != "$got" ]; then
    fail "hash mismatch ${path}"
  fi
done < <(jq -c '.files[]' "${SKILL}/PROVENANCE.json")

set +e
bash "${ROOT}/scripts/update-composio-skill.sh" >/tmp/composio-usage.txt 2>&1
no_arg=$?
bash "${ROOT}/scripts/update-composio-skill.sh" main >/tmp/composio-branch.txt 2>&1
branch_arg=$?
set -e
if [ "$no_arg" -eq 0 ] || [ "$branch_arg" -eq 0 ]; then
  fail "update script accepted a missing or branch ref"
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi
echo "composio skill tests passed."
