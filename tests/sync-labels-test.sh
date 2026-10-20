#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/failbin"
cat >"$TMP/bin/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${GH_LOG:?}"
if [ "$1" = "repo" ]; then
  printf '%s\n' "owner/name"
fi
exit 0
EOF
printf '%s\n' '#!/bin/sh' 'exit 1' >"$TMP/failbin/node"
chmod +x "$TMP/bin/gh" "$TMP/failbin/node"
export GH_LOG="$TMP/gh.log"
export PATH="$TMP/bin:$PATH"
touch "$GH_LOG"
bash "$ROOT/scripts/sync-labels.sh" owner/name >/dev/null
grep -q 'label create ci ' "$GH_LOG" || { echo "sync-labels-test FAIL: ci label missing" >&2; exit 1; }
grep -q -- '--repo owner/name' "$GH_LOG" || { echo "sync-labels-test FAIL: repo missing" >&2; exit 1; }
if PATH="$TMP/failbin:$PATH" bash "$ROOT/scripts/sync-labels.sh" owner/name >/dev/null 2>&1; then
  echo "sync-labels-test FAIL: node failure was ignored" >&2
  exit 1
fi
echo "sync-labels-test passed"
