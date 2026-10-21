#!/usr/bin/env bash
# postToolUseFailure: one redacted JSON line. Stdout stays {}.
set -euo pipefail

state_dir="${HOOKS_STATE_DIR:-.cursor/hooks/state}"
stdin="$(cat || true)"
mkdir -p "$state_dir"

# shellcheck disable=SC2016
printf '%s' "$stdin" | STATE_DIR="$state_dir" node -e '
  const fs = require("fs");
  const path = require("path");
  let s = "";
  process.stdin.on("data", (d) => { s += d; });
  process.stdin.on("end", () => {
    let tool = "";
    let error = "";
    try {
      const j = JSON.parse(s);
      if (j && typeof j.tool_name === "string") tool = j.tool_name;
      if (j && typeof j.error_message === "string") error = j.error_message;
      else if (j && typeof j.error === "string") error = j.error;
    } catch (e) {
      error = "";
    }
    error = error
      .replace(/Bearer\s+\S+/gi, "Bearer [REDACTED]")
      .replace(/\b(?:ghp_|gho_|github_pat_|sk-|xox[baprs]-)[A-Za-z0-9_-]+/g, "[REDACTED]")
      .replace(/((?:token|api[_-]?key|password)\s*[:=]\s*)\S+/gi, "$1[REDACTED]");
    if (error.length > 240) error = error.slice(0, 240);
    const line = JSON.stringify({
      ts: new Date().toISOString(),
      tool,
      error
    });
    const dest = path.join(process.env.STATE_DIR, "tool-failures.jsonl");
    fs.mkdirSync(process.env.STATE_DIR, { recursive: true });
    fs.appendFileSync(dest, line + "\n");
  });
' >/dev/null

printf '{}\n'
exit 0
