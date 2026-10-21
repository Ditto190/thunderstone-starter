#!/usr/bin/env bash
# One entry for opt-in Cursor hooks. Routes on hook_event_name and always exits 0.
set -euo pipefail

events_dir="${HOOKS_EVENTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/events}"
budget="${HOOKS_BUDGET_SEC:-4}"
case "$budget" in
  ''|*[!0-9]*) budget=4 ;;
esac

stdin="$(cat || true)"

event="$(
  printf '%s' "$stdin" | node -e '
    let s = "";
    process.stdin.on("data", (d) => { s += d; });
    process.stdin.on("end", () => {
      try {
        const j = JSON.parse(s);
        const name = j && typeof j.hook_event_name === "string" ? j.hook_event_name : "";
        process.stdout.write(name);
      } catch (e) {
        process.exit(2);
      }
    });
  ' 2>/dev/null || true
)"
parse_rc=$?

emit_empty() {
  printf '{}\n'
}

if [ "$parse_rc" -ne 0 ] || [ -z "$event" ]; then
  emit_empty
  exit 0
fi

handler=""
case "$event" in
  sessionStart) handler="session-start.sh" ;;
  stop) handler="stop.sh" ;;
  postToolUseFailure) handler="tool-failure.sh" ;;
  afterFileEdit) handler="report-edit.sh" ;;
  *)
    emit_empty
    exit 0
    ;;
esac

script="${events_dir}/${handler}"
if [ ! -f "$script" ]; then
  emit_empty
  exit 0
fi

out=""
rc=0
if command -v timeout >/dev/null 2>&1; then
  out="$(printf '%s' "$stdin" | timeout --signal=KILL "$budget" bash "$script" 2>/dev/null)" || rc=$?
else
  tmp="$(mktemp)"
  printf '%s' "$stdin" | bash "$script" >"$tmp" 2>/dev/null &
  pid=$!
  deadline=$((SECONDS + budget))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      rm -f "$tmp"
      emit_empty
      exit 0
    fi
    sleep 0.1
  done
  wait "$pid" || rc=$?
  out="$(cat "$tmp" 2>/dev/null || true)"
  rm -f "$tmp"
fi

if [ "$rc" -ne 0 ]; then
  emit_empty
  exit 0
fi

if ! printf '%s' "$out" | node -e '
  let s = "";
  process.stdin.on("data", (d) => { s += d; });
  process.stdin.on("end", () => {
    const t = s.trim();
    if (!t) process.exit(2);
    const j = JSON.parse(t);
    if (j === null || typeof j !== "object" || Array.isArray(j)) process.exit(2);
  });
' 2>/dev/null; then
  emit_empty
  exit 0
fi

printf '%s\n' "$(printf '%s' "$out" | tr -d '\r')"
exit 0
