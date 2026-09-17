#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$ROOT"/workspace/{briefs,reports,exports} "$ROOT/.state"
command -v tmux >/dev/null || { echo "Run sh scripts/bootstrap.sh first." >&2; exit 1; }
# A kernel file lock works even before the first tmux server exists.
exec 9>"$ROOT/.state/resume.lock"
flock -w 15 9
if ! tmux has-session -t '=thunderstone' 2>/dev/null; then
  tmux new-session -d -s thunderstone -c "$ROOT" 'exec bash -l' 9>&-
fi
echo "Ready: tmux attach -t thunderstone. No paid agent task started."
