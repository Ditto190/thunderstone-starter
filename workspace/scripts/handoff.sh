#!/usr/bin/env bash
# handoff.sh — path-only bot-to-bot handoff.
# Usage: handoff.sh <from> <to> <slug> "<ASK>" [OUT] [DUE] [PRI] < payload
#        handoff.sh --check "<message>"   # exit 1 if >300 chars or missing schema
set -euo pipefail
DIR="${THUNDERSTONE_ROOT:-/workspace/thunderstone}/handoffs"
LOG=$DIR/.handoff-audit.log
MAX=300
SAFE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
if [[ "${1:-}" == "--check" ]]; then
  mkdir -p "$DIR"
  m="${2:-$(cat)}"; n=${#m}
  if (( n > MAX )) || ! grep -q '^ASK:' <<<"$m"; then
    echo "$(date -Is) FAIL len=$n" >>"$LOG"; echo "handoff: FAIL ($n chars or no ASK:). Move payload to file." >&2; exit 1
  fi; exit 0
fi
[[ $# -ge 4 ]] || { sed -n '2,4p' "$0"; exit 2; }
from=$1 to=$2 slug=$3 ask=$4 out=${5:-"reply<=5 lines"} due=${6:-next-turn} pri=${7:-false}
[[ "$from" =~ $SAFE && "$to" =~ $SAFE && "$slug" =~ $SAFE ]] || { echo "handoff: bad from/to/slug" >&2; exit 2; }
mkdir -p "$DIR"
f="$DIR/$(date +%Y%m%d-%H%M%S)-$from-$to-$slug.md"
cat >"$f"
in="$f"
if (( $(wc -c <"$f") > 2000 )); then
  min="${f%.md}.min.md"
  if command -v lean-ctx >/dev/null; then lean-ctx -c "cat '$f'" >"$min" 2>/dev/null || head -c 2000 "$f" >"$min"
  else head -c 2000 "$f" >"$min"; fi
  in="$min (full: $f)"
fi
msg=$(printf 'ASK: %s\nIN: %s\nOUT: %s\nDUE: %s\nPRI: %s' "$ask" "$in" "$out" "$due" "$pri")
"$0" --check "$msg" || { msg=$(printf 'ASK: see file\nIN: %s\nPRI: %s' "$f" "$pri"); }
echo "$(date -Is) OK $from->$to len=${#msg} $f" >>"$LOG"
printf '%s\n' "$msg"
