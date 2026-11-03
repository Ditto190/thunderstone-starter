#!/usr/bin/env bash
# handoff.sh — path-only bot-to-bot handoff (COMMS SPEC 2026-11-02).
# Usage: handoff.sh <from> <to> <slug> "<ASK>" [OUT] [DUE] [PRI] < payload
#        handoff.sh --check FILE          # line 1 = 1-line JSON header
#        handoff.sh --check "<message>"   # JSON header or legacy ASK: message
#        handoff.sh --check               # read message from stdin
# Exit 0 on pass; 1 on fail (one-line reason on stderr).
set -euo pipefail
DIR="${HANDOFF_DIR:-${THUNDERSTONE_ROOT:-/workspace/thunderstone}/handoffs}"
LOG=$DIR/.handoff-audit.log
MAX=300
SAFE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
# Fixed key order: required prefix, then optional pri, due, body (each at most once, in that order).

_audit() { mkdir -p "$DIR"; echo "$(date -Is) $*" >>"$LOG"; }

_fail() {
  local reason=$1
  _audit "FAIL $reason"
  echo "handoff: FAIL $reason" >&2
  exit 1
}

# Validate one-line JSON header object. Prints nothing on success.
_check_json_header() {
  local h=$1
  command -v jq >/dev/null || _fail "jq missing"
  # Single line, no trailing content issues: reject embedded newlines
  if [[ "$h" == *$'\n'* ]]; then
    _fail "header must be a single line"
  fi
  local n=${#h}
  if (( n > MAX )); then
    _fail "header $n chars > $MAX; move long values to body path"
  fi
  if ! jq -e 'type == "object"' <<<"$h" >/dev/null 2>&1; then
    _fail "not a 1-line JSON object"
  fi
  local miss
  miss=$(jq -r '
    [ ("goal","owner","success","evidence_path","approval","return") as $k
      | select(has($k) | not) | $k
    ] | join(",")
  ' <<<"$h")
  [[ -z "$miss" ]] || _fail "missing keys: $miss"

  # Fixed key order: required six first, then optional pri/due/body in that order only.
  local keys
  keys=$(jq -r 'keys_unsorted | join(",")' <<<"$h")
  case "$keys" in
    goal,owner,success,evidence_path,approval,return) ;;
    goal,owner,success,evidence_path,approval,return,pri) ;;
    goal,owner,success,evidence_path,approval,return,due) ;;
    goal,owner,success,evidence_path,approval,return,body) ;;
    goal,owner,success,evidence_path,approval,return,pri,due) ;;
    goal,owner,success,evidence_path,approval,return,pri,body) ;;
    goal,owner,success,evidence_path,approval,return,due,body) ;;
    goal,owner,success,evidence_path,approval,return,pri,due,body) ;;
    *) _fail "key order invalid (got: $keys); want goal,owner,success,evidence_path,approval,return[,pri][,due][,body]" ;;
  esac

  local ap
  ap=$(jq -r '.approval' <<<"$h")
  # ro|stage exact; dt:"…"@ISO (YYYY-MM-DDTHH:MM + offset/Z), whole-string match.
  if [[ "$ap" == "ro" || "$ap" == "stage" ]]; then
    :
  elif [[ "$ap" == dt:* ]]; then
    dt_re='^dt:"[^"]+"@[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}(:[0-9]{2})?)$'
    if [[ ! "$ap" =~ $dt_re ]]; then
      _fail "approval dt: form must be dt:\"<exact DT words>\"@<ISO time> (got: ${ap:0:80})"
    fi
  else
    _fail "approval must match ro|stage|dt:\"…\"@<time> (got: ${ap:0:60})"
  fi

  if jq -e 'has("pri")' <<<"$h" >/dev/null 2>&1; then
    local pri; pri=$(jq -r '.pri' <<<"$h")
    case "$pri" in P0|P1|P2|P3) ;; *) _fail "pri must be P0|P1|P2|P3 (got: $pri)" ;; esac
  fi
  # Spec: path+<=5 or path+N with N in 1..5
  if jq -e 'has("return")' <<<"$h" >/dev/null 2>&1; then
    local ret; ret=$(jq -r '.return' <<<"$h")
    case "$ret" in
      'path+<=5'|path+[1-5]) ;;
      *) _fail "return must be path+<=5 or path+N (N=1..5) (got: ${ret:0:40})" ;;
    esac
  fi
}

_check_message() {
  local m=$1
  # Trim a single trailing newline for length (stdin/echo often adds one)
  m=${m%$'\n'}
  if [[ "$m" == \{* ]]; then
    _check_json_header "$m"
    return 0
  fi
  # Legacy ASK: branch
  n=${#m}
  if (( n > MAX )) || ! grep -q '^ASK:' <<<"$m"; then
    _fail "($n chars or no ASK:). Move payload to file or use JSON header."
  fi
}

if [[ "${1:-}" == "--check" ]]; then
  if [[ -n "${2:-}" && -f "${2}" ]]; then
    f=$2
    [[ -r "$f" ]] || _fail "not readable: $f"
    h=$(head -n 1 -- "$f")
    _check_json_header "$h"
    exit 0
  fi
  if [[ -n "${2:-}" ]]; then
    m=$2
  else
    m=$(cat)
  fi
  _check_message "$m"
  exit 0
fi

[[ $# -ge 4 ]] || { sed -n '2,6p' "$0"; exit 2; }
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
_audit "OK $from->$to len=${#msg} $f"
printf '%s\n' "$msg"
