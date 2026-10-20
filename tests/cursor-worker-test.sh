#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n scripts/cursor-worker.sh

cfg="$(CURSOR_WORKER_NAME='' CURSOR_WORKER_SESSION='' CURSOR_WORKER_DIR='' node scripts/env-run.mjs node -e '
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

# ensure must not inherit autostart or the live worker session
test_session="thunderstone-worker-test-$$"
CURSOR_WORKER_AUTOSTART=0 \
  CURSOR_WORKER_SESSION="$test_session" \
  bash scripts/cursor-worker.sh ensure

status_out="$(CURSOR_WORKER_SESSION="$test_session" bash scripts/cursor-worker.sh status 2>/dev/null)"
printf '%s\n' "$status_out" | grep -q "WORKER_SESSION=stopped ($test_session)"

# start must keep a quoted name and directory as single arguments
stub="$(mktemp -d)"
trap 'rm -rf "$stub"' EXIT
mkdir -p "$stub/.local/bin"
cat >"$stub/.local/bin/tmux" <<'EOF'
#!/bin/sh
if [ "$1" = new-session ]; then
  printf '%s\n' "$@"
  exit 0
fi
exit 1
EOF
printf '%s\n' '#!/bin/sh' 'exit 0' >"$stub/.local/bin/agent"
chmod +x "$stub/.local/bin/tmux" "$stub/.local/bin/agent"
quoted_name='qa"worker'
quoted_dir="${TMPDIR:-/tmp}/qa\"dir"
launch="$(
  HOME="$stub" \
    CURSOR_WORKER_NAME="$quoted_name" \
    CURSOR_WORKER_DIR="$quoted_dir" \
    CURSOR_WORKER_SESSION="quote-test-$$" \
    CURSOR_WORKER_AUTOSTART=0 \
    bash scripts/cursor-worker.sh start
)"
line="$(grep -m1 '^cd ' <<<"$launch")"
# Parse the tmux command line the way a shell would (test-controlled input only).
parts=()
eval "parts=(${line#* && exec })"
got_name="" got_dir=""
for ((i = 0; i < ${#parts[@]} - 1; i++)); do
  case "${parts[i]}" in
    --name) got_name="${parts[i + 1]}" ;;
    --worker-dir) got_dir="${parts[i + 1]}" ;;
  esac
done
if [ "$got_name" != "$quoted_name" ] || [ "$got_dir" != "$quoted_dir" ]; then
  echo "quoted worker arguments were split" >&2
  exit 1
fi

echo "cursor-worker tests passed."
