#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if bash scripts/validate-brief.sh "${TMP}/missing.md" 2>/dev/null; then
  echo "expected missing brief to fail"
  exit 1
fi

fence="$(printf '\140\140\140')"
printf '# Title\n\n%s\n## Goal\n## Acceptance\n%s\n' "$fence" "$fence" >"${TMP}/fenced.md"
if bash scripts/validate-brief.sh "${TMP}/fenced.md" 2>/dev/null; then
  echo "expected fenced headings to fail"
  exit 1
fi

printf '# Title only\n' >"${TMP}/no-goal.md"
if bash scripts/validate-brief.sh "${TMP}/no-goal.md" 2>/dev/null; then
  echo "expected missing goal to fail"
  exit 1
fi

printf '# Title\n\n## Goal\n\nDo the thing.\n' >"${TMP}/no-accept.md"
if bash scripts/validate-brief.sh "${TMP}/no-accept.md" 2>/dev/null; then
  echo "expected missing acceptance to fail"
  exit 1
fi

printf '# Title\n\n## Objective\n\nDo the thing.\n\n## Acceptance\n\n- done\n' >"${TMP}/ok.md"
bash scripts/validate-brief.sh "${TMP}/ok.md" | grep -q brief_valid
echo "validate-brief-test passed"
