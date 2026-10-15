#!/usr/bin/env bash
# Manage the Cursor CLI self-hosted worker (My Machines) in tmux.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"

usage() {
  cat <<'EOF'
Usage: bash scripts/cursor-worker.sh <command>

Commands:
  start    Start the worker in a dedicated tmux session (idempotent).
  stop     Stop the worker tmux session.
  status   Print worker session and optional agent worker debug output.
  ensure   Start only when CURSOR_WORKER_AUTOSTART=1 and worker is not running.

Configure via .env.local (see config/cursor-worker.example.env).
Requires: tmux, Cursor CLI (agent), and agent login or CURSOR_API_KEY.
EOF
}

worker_env() {
  node "$ROOT/scripts/env-run.mjs" node -e '
    const root = process.argv[1];
    const d = Object.assign({}, process.env);
    const name = d.CURSOR_WORKER_NAME || "grok-shared";
    const session = d.CURSOR_WORKER_SESSION || "thunderstone-worker";
    const dir = d.CURSOR_WORKER_DIR || root;
    const autostart = d.CURSOR_WORKER_AUTOSTART === "1" ? "1" : "0";
    const computer = d.CURSOR_WORKER_COMPUTER_USE === "1" ? "1" : "0";
    process.stdout.write(JSON.stringify({ name, session, dir, autostart, computer }));
  ' "$ROOT"
}

session_running() {
  local session="$1"
  tmux has-session -t "=${session}" 2>/dev/null
}

require_tmux() {
  command -v tmux >/dev/null || {
    echo "tmux required. Run sh scripts/bootstrap.sh first." >&2
    exit 1
  }
}

require_agent() {
  command -v agent >/dev/null || {
    echo "Cursor CLI (agent) not found. Run bootstrap or install from cursor.com/docs/cli/installation." >&2
    exit 1
  }
}

start_worker() {
  require_tmux
  require_agent
  local cfg name session dir computer
  cfg="$(worker_env)"
  name="$(node -e "console.log(JSON.parse(process.argv[1]).name)" "$cfg")"
  session="$(node -e "console.log(JSON.parse(process.argv[1]).session)" "$cfg")"
  dir="$(node -e "console.log(JSON.parse(process.argv[1]).dir)" "$cfg")"
  computer="$(node -e "console.log(JSON.parse(process.argv[1]).computer)" "$cfg")"

  if session_running "$session"; then
    echo "Worker tmux session already running: $session"
    return 0
  fi

  local inner="cd \"$ROOT\" && exec node scripts/env-run.mjs agent worker start --name \"$name\" --worker-dir \"$dir\""
  if [ "$computer" = "1" ]; then
    inner+=" --computer-use"
  fi

  tmux new-session -d -s "$session" -c "$ROOT" "$inner"
  echo "Started Cursor worker name=$name session=$session dir=$dir"
  echo "In Cursor Cloud: pick My Machines → $name (or worker=$name in triggers)."
}

stop_worker() {
  require_tmux
  local cfg session
  cfg="$(worker_env)"
  session="$(node -e "console.log(JSON.parse(process.argv[1]).session)" "$cfg")"
  if session_running "$session"; then
    tmux kill-session -t "$session"
    echo "Stopped tmux session: $session"
  else
    echo "Worker tmux session not running: $session"
  fi
}

status_worker() {
  require_tmux
  local cfg name session dir
  cfg="$(worker_env)"
  name="$(node -e "console.log(JSON.parse(process.argv[1]).name)" "$cfg")"
  session="$(node -e "console.log(JSON.parse(process.argv[1]).session)" "$cfg")"
  dir="$(node -e "console.log(JSON.parse(process.argv[1]).dir)" "$cfg")"

  if session_running "$session"; then
    echo "WORKER_SESSION=running ($session)"
  else
    echo "WORKER_SESSION=stopped ($session)"
  fi
  echo "WORKER_NAME=$name"
  echo "WORKER_DIR=$dir"

  if command -v agent >/dev/null; then
    if node "$ROOT/scripts/env-run.mjs" agent worker debug 2>/dev/null; then
      :
    else
      echo "WORKER_DEBUG=unavailable (login or set CURSOR_API_KEY, then retry)"
    fi
  else
    echo "WORKER_DEBUG=skipped (agent CLI missing)"
  fi
}

ensure_worker() {
  local cfg autostart
  cfg="$(worker_env)"
  autostart="$(node -e "console.log(JSON.parse(process.argv[1]).autostart)" "$cfg")"
  if [ "$autostart" != "1" ]; then
    return 0
  fi
  start_worker
}

cmd="${1:-}"
case "$cmd" in
  start) start_worker ;;
  stop) stop_worker ;;
  status) status_worker ;;
  ensure) ensure_worker ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
