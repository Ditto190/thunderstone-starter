#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n scripts/cursor-worker.sh

cfg="$(node scripts/env-run.mjs node -e '
  const root = process.argv[1];
  const d = Object.assign({}, process.env);
  const name = d.CURSOR_WORKER_NAME || "grok-shared";
  const session = d.CURSOR_WORKER_SESSION || "thunderstone-worker";
  const dir = d.CURSOR_WORKER_DIR || root;
  process.stdout.write(JSON.stringify({ name, session, dir }));
' "$ROOT")"

name="$(node -e "console.log(JSON.parse(process.argv[1]).name)" "$cfg")"
session="$(node -e "console.log(JSON.parse(process.argv[1]).session)" "$cfg")"
dir="$(node -e "console.log(JSON.parse(process.argv[1]).dir)" "$cfg")"

[[ "$name" == "grok-shared" ]] || { echo "expected default worker name"; exit 1; }
[[ "$session" == "thunderstone-worker" ]] || { echo "expected default session"; exit 1; }
[[ "$dir" == "$ROOT" ]] || { echo "expected worker dir root"; exit 1; }

CURSOR_WORKER_NAME=custom-test \
  CURSOR_WORKER_SESSION=custom-session \
  node scripts/env-run.mjs node -e '
    const root = process.argv[1];
    const d = process.env;
    if (d.CURSOR_WORKER_NAME !== "custom-test") process.exit(1);
    if (d.CURSOR_WORKER_SESSION !== "custom-session") process.exit(1);
  ' "$ROOT"

# ensure is a no-op when autostart is off (default)
bash scripts/cursor-worker.sh ensure

# status should not fail when worker is stopped
bash scripts/cursor-worker.sh status | grep -q 'WORKER_SESSION=stopped'

echo "cursor-worker tests passed."
