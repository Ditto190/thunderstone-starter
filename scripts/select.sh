#!/usr/bin/env bash
# select.sh "<task text>" [--kind skill|agent|plugin] [--top N] [--json] [--root DIR] [--external]
# Picks a skill for a task. Exit 0 with TSV (score kind id cost path hitwords),
# exit 1 + NO_MATCH when nothing scores (fall back to house-rules routing).
#
# Private deny-by-default: only the canonical root is indexed and scope: private
# items are never returned (see catalog.mjs). Task text stays on this box unless
# --external is given; even then it is only used locally to grep a public file.
#   THUNDERSTONE_SKILLS_ROOT  canonical skills root (default ../skills next to this script)
#   CATALOG                   catalog.json to use (default ../catalog/catalog.json; generated
#                             into a temp file when absent). Unset CATALOG plus --root always
#                             regenerates from that root and ignores the default file.
#   EXTERNAL_LLMS_URL         public llms.txt for --external (default awesome-copilot)
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAT="${CATALOG:-$D/../catalog/catalog.json}"
EXT_URL="${EXTERNAL_LLMS_URL:-https://awesome-copilot.github.com/llms.txt}"
usage() { echo 'usage: select.sh "<task>" [--kind k] [--top N] [--json] [--root DIR] [--external]' >&2; exit 2; }
[ $# -ge 1 ] || usage
task="$1"; shift
ext=0; args=(); rootargs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --external) ext=1 ;;
    --root) [ $# -ge 2 ] || usage; rootargs=(--root "$2"); args+=("$1" "$2"); shift ;;
    --kind|--top) [ $# -ge 2 ] || usage; args+=("$1" "$2"); shift ;;
    --json) args+=("$1") ;;
    *) usage ;;
  esac
  shift
done
# --root without an explicit CATALOG must not reuse ../catalog/catalog.json.
if { [ -n "${rootargs[0]:-}" ] && [ -z "${CATALOG+x}" ]; } || [ ! -f "$CAT" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  node "$D/catalog.mjs" gen ${rootargs[@]+"${rootargs[@]}"} >"$tmp/catalog.json"
  CAT="$tmp/catalog.json"
fi
rc=0
node "$D/catalog.mjs" select "$CAT" "$task" ${args[@]+"${args[@]}"} || rc=$?
if [ "$ext" = 1 ]; then
  # Optional, read-only, public. The request carries NO task text; matching is local.
  echo "--- external (awesome-copilot llms.txt, not installed) ---"
  list="$(curl -fsSL --max-time 15 "$EXT_URL" 2>/dev/null || true)"
  re="$(printf '%s\n' "$task" | tr -cs 'A-Za-z0-9' '\n' | awk 'length>3' | paste -sd'|')"
  if [ -n "$re" ]; then
    printf '%s\n' "$list" | { grep -E '^- \[' || true; } | { grep -i -E "$re" || true; } | head -3 | cut -c1-240 || true
  fi
fi
exit "$rc"
