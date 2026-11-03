#!/usr/bin/env bash
# ci-mimic.sh: run the CI validate job locally, the way GitHub runners see it.
# Strips BASH_ENV/ENV and hides box-only tools (and the Cursor CLI) from PATH,
# then runs the CI steps. Terse output: one line per step, full log on disk.
# Usage: ci-mimic.sh [--hide "rclone fzf"] [--log FILE] [-- CMD...]
#   default steps: git diff --check (worktree + staged), npm test
#   default hide: rclone fzf (ci.yml apt-installs shellcheck + tmux; jq ships on runners).
#   strict: --hide "tmux rclone fzf". CI_MIMIC_HIDE also overrides. agent/cursor-agent always hidden.
set -euo pipefail
if [[ -n "${BASH_ENV:-}" || -n "${ENV:-}" ]]; then
  exec env -u BASH_ENV -u ENV bash "${BASH_SOURCE[0]}" "$@"
fi
root="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
hide="${CI_MIMIC_HIDE:-rclone fzf}"
log=""
cmd=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hide) hide="${2:?--hide needs a list}"; shift 2 ;;
    --log) log="${2:?--log needs a file}"; shift 2 ;;
    --) shift; cmd=("$@"); break ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "ci-mimic: unknown arg $1" >&2; exit 2 ;;
  esac
done
hide="$hide agent cursor-agent"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
shim="$tmp/bin"
mkdir -p "$shim"
auto_log=0
if [[ -z "$log" ]]; then log="$(mktemp "${TMPDIR:-/tmp}/ci-mimic.XXXXXX")"; auto_log=1; fi
: >"$log"

# Mirror every PATH executable as a symlink, skipping hidden names. First match wins, like PATH.
IFS=: read -r -a dirs <<<"$PATH"
for d in "${dirs[@]}"; do
  [[ -d "$d" ]] || continue
  for f in "$d"/*; do
    n="${f##*/}"
    [[ -x "$f" && ! -d "$f" ]] || continue
    [[ -e "$shim/$n" || -L "$shim/$n" ]] && continue
    case " $hide " in *" $n "*) continue ;; esac
    ln -s "$f" "$shim/$n"
  done
done

run_step() {
  local name="$1" rc=0
  shift
  echo "== $name" >>"$log"
  (cd "$root" && env -u BASH_ENV -u ENV PATH="$shim" HUSKY=0 CI=true "$@") >>"$log" 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then echo "ci-mimic: ok   $name"; else
    echo "ci-mimic: FAIL $name rc=$rc (log: $log)"
    tail -n 15 "$log" | sed 's/^/  | /'
  fi
  return "$rc"
}

rc=0
if [[ ${#cmd[@]} -gt 0 ]]; then
  run_step "${cmd[*]}" "${cmd[@]}" || rc=$?
else
  run_step "git diff --check" git diff --check || rc=$?
  run_step "git diff --cached --check" git diff --cached --check || rc=$?
  run_step "npm test" npm test || rc=$?
fi
if [[ "$rc" -eq 0 ]]; then echo "ci-mimic: PASS (hidden: $hide)"; else echo "ci-mimic: FAIL (hidden: $hide)"; fi
# Keep a caller-supplied log always; an auto log only when something failed.
if [[ "$rc" -eq 0 && "$auto_log" -eq 1 ]]; then rm -f "$log"; fi
exit "$rc"
