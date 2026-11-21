#!/usr/bin/env bash
# Local session snapshot (no network, no agents). save on shell EXIT; show on resume/terminal.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.state"
SNAP="$STATE/session-snapshot.txt"
PREV="$STATE/session-snapshot.prev.txt"
LOCK="$STATE/session-snapshot.lock"

STARTER="${THUNDERSTONE_REPO:-$ROOT}"
MODME="${MODME_REPO:-/workspace/modme-ui-01}"
OPS="${THUNDERSTONE_WORKSPACE:-/workspace/thunderstone}"

repo_block() {
  local name="$1" dir="$2"
  [[ -d "$dir/.git" ]] || return 0
  local branch wt diff_line
  branch="$(git -C "$dir" branch --show-current 2>/dev/null || echo '?')"
  wt="$(git -C "$dir" worktree list 2>/dev/null | wc -l | tr -d ' ')"
  diff_line="$(timeout 2 git -C "$dir" diff --shortstat HEAD 2>/dev/null | tail -1 || true)"
  [[ -z "$diff_line" ]] && diff_line="clean"
  printf '[%s] branch=%s wt=%s %s\n' "$name" "$branch" "$wt" "$diff_line"
  timeout 2 git -C "$dir" status -sb 2>/dev/null | head -2 | sed 's/^/  /' || true
}

save() {
  mkdir -p "$STATE"
  (
    flock -w 2 9 || exit 0
    [[ -f "$SNAP" ]] && cp -f "$SNAP" "$PREV"
    {
      echo "saved_at=$(date -Iseconds)"
      echo "host=$(hostname -s 2>/dev/null || hostname)"
      echo "disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
      if [[ -r "$OPS/state/health-last.json" ]]; then
        echo "health=$(jq -r '.status // "?"' "$OPS/state/health-last.json" 2>/dev/null || echo '?')"
      fi
      repo_block starter "$STARTER"
      repo_block modme "$MODME"
      if compgen -G '/workspace/wt-*' >/dev/null; then
        wts=(/workspace/wt-*); extra=${#wts[@]}
        echo "[workspaces] wt_dirs=$extra"
        for w in "${wts[@]}"; do
          sb=$(timeout 1 git -C "$w" status -sb 2>/dev/null | head -1 || echo '?')
          printf '  %s %s\n' "$(basename "$w")" "$sb"
        done
      fi
    } >"$SNAP.tmp"
    mv -f "$SNAP.tmp" "$SNAP"
  ) 9>"$LOCK"
}

show() {
  [[ -f "$SNAP" ]] || {
    echo "session-snapshot: (none yet — close a tmux shell to record)"
    return 0
  }
  echo "── thunderstone session snapshot ──"
  sed -n '1,40p' "$SNAP"
  if [[ -f "$PREV" ]]; then
    echo "── Δ since previous save ──"
    _delta_line starter "$PREV" "$SNAP"
    _delta_line modme "$PREV" "$SNAP"
  fi
  echo "── manual: session-snapshot.sh save | show ──"
}

_delta_line() {
  local tag="$1" a="$2" b="$3"
  local da db
  da=$(awk -v t="\\[$tag\\]" '$0 ~ t {print; getline; print; exit}' "$a" 2>/dev/null)
  db=$(awk -v t="\\[$tag\\]" '$0 ~ t {print; getline; print; exit}' "$b" 2>/dev/null)
  [[ "$da" != "$db" && -n "$db" ]] && echo "  $tag changed"
}

case "${1:-show}" in
  save) save ;;
  show) show ;;
  *) echo "usage: session-snapshot.sh save|show" >&2; exit 2 ;;
esac