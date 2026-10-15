#!/usr/bin/env bash
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

load_worker_cfg() {
  local line
  line="$(worker_env | node -e '
    const j = JSON.parse(require("fs").readFileSync(0, "utf8"));
    process.stdout.write([j.name, j.session, j.dir, j.autostart, j.computer].join("\t"));
  ')"
  IFS=$'\t' read -r WORKER_NAME WORKER_SESSION WORKER_DIR WORKER_AUTOSTART WORKER_COMPUTER_USE <<<"$line"
}

session_running() {
  tmux has-session -t "=$WORKER_SESSION" 2>/dev/null
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
  load_worker_cfg

  if session_running; then
    echo "Worker tmux session already running: $WORKER_SESSION"
    return 0
  fi

  local inner="cd \"$ROOT\" && exec node scripts/env-run.mjs agent worker start --name \"$WORKER_NAME\" --worker-dir \"$WORKER_DIR\""
  if [ "$WORKER_COMPUTER_USE" = "1" ]; then
    inner+=" --computer-use"
  fi

  tmux new-session -d -s "$WORKER_SESSION" -c "$ROOT" "$inner"
  echo "Started Cursor worker name=$WORKER_NAME session=$WORKER_SESSION dir=$WORKER_DIR"
  echo "In Cursor Cloud: pick My Machines → $WORKER_NAME (or worker=$WORKER_NAME in triggers)."
}

stop_worker() {
  require_tmux
  load_worker_cfg
  if session_running; then
    tmux kill-session -t "$WORKER_SESSION"
    echo "Stopped tmux session: $WORKER_SESSION"
  else
    echo "Worker tmux session not running: $WORKER_SESSION"
  fi
}

status_worker() {
  require_tmux
  load_worker_cfg

  if session_running; then
    echo "WORKER_SESSION=running ($WORKER_SESSION)"
  else
    echo "WORKER_SESSION=stopped ($WORKER_SESSION)"
  fi
  echo "WORKER_NAME=$WORKER_NAME"
  echo "WORKER_DIR=$WORKER_DIR"

  if ! command -v agent >/dev/null; then
    echo "WORKER_DEBUG=skipped (agent CLI missing)"
    return 0
  fi
  if node "$ROOT/scripts/env-run.mjs" agent worker debug >&2; then
    echo "WORKER_DEBUG=ok"
  else
    echo "WORKER_DEBUG=unavailable (login or set CURSOR_API_KEY, then retry)"
  fi
}

ensure_worker() {
  load_worker_cfg
  if [ "$WORKER_AUTOSTART" != "1" ]; then
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
