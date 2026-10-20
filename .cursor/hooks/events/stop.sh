#!/usr/bin/env bash
# stop: receipt stub when a brief is active. Stdout stays {}.
set -euo pipefail

state_dir="${HOOKS_STATE_DIR:-.cursor/hooks/state}"
stdin="$(cat || true)"

if [ -n "${THUNDERSTONE_ROOT:-}" ]; then
  brief="${THUNDERSTONE_ROOT}/state/active-brief"
else
  brief=".state/active-brief"
fi

if [ ! -e "$brief" ]; then
  printf '{}\n'
  exit 0
fi

session_key="$(
  printf '%s' "$stdin" | node -e '
    const crypto = require("crypto");
    let s = "";
    process.stdin.on("data", (d) => { s += d; });
    process.stdin.on("end", () => {
      let id = "";
      try {
        const j = JSON.parse(s);
        if (j && typeof j.conversation_id === "string" && j.conversation_id) id = j.conversation_id;
        else if (j && typeof j.session_id === "string" && j.session_id) id = j.session_id;
      } catch (e) {}
      if (!id) id = crypto.createHash("sha256").update(s).digest("hex");
      process.stdout.write(id.replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 120));
    });
  '
)"

mkdir -p "${state_dir}/seen" "${state_dir}/receipts"
marker="${state_dir}/seen/stop-${session_key}"
if [ -f "$marker" ]; then
  printf '{}\n'
  exit 0
fi
: >"$marker"
printf 'receipt\nstatus=stub\n' >"${state_dir}/receipts/${session_key}.stub"
printf '{}\n'
exit 0
