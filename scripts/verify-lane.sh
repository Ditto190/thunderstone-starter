#!/usr/bin/env bash
# verify-lane.sh: check a lane's claims before Git-Scout handoff. Never trust a self-report.
# Usage: verify-lane.sh [--worktree DIR] [--branch NAME] [--paths "a b"] [--evidence FILE] [--ci]
#   --worktree  repo/worktree to check (default: this repo)
#   --branch    expected current branch
#   --paths     exact set of paths that should be staged (space-separated, order free)
#   --path      one expected staged path (repeatable; use for names with spaces)
#   --evidence  artifact whose line 1 must be the 1-line JSON brief header
#               (keys goal, owner, success, evidence_path, approval, return)
#   --ci        also run scripts/ci-mimic.sh in the worktree
# Always: something staged, no staged path also has unstaged edits, git diff --cached --check.
# Exit 0 when every check passes, 1 otherwise. One line per check.
set -euo pipefail
here="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wt="$here" branch="" paths="" evidence="" ci=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree) wt="${2:?}"; shift 2 ;;
    --branch) branch="${2:?}"; shift 2 ;;
    --paths) paths+="$(tr ' ' '\n' <<<"${2:?}")"$'\n'; shift 2 ;;
    --path) paths+="${2:?}"$'\n'; shift 2 ;;
    --evidence) evidence="${2:?}"; shift 2 ;;
    --ci) ci=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "verify-lane: unknown arg $1" >&2; exit 2 ;;
  esac
done
fail=0
ok() { echo "verify-lane: ok   $*"; }
bad() { echo "verify-lane: FAIL $*"; fail=1; }

git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { bad "not a git worktree: $wt"; exit 1; }
cur="$(git -C "$wt" branch --show-current)"
if [[ -n "$branch" ]]; then
  if [[ "$cur" == "$branch" ]]; then ok "branch $cur"; else bad "branch is '${cur:-DETACHED}', want $branch"; fi
fi

# NUL-delimited (-z): literal pathnames, no core.quotePath escapes.
# --no-renames: staged rename sources appear as deletions so a recreated old name is caught.
_nul_lines() { LC_ALL=C sort -zu | tr '\0' '\n' | sed '/^$/d'; }
staged="$(git -C "$wt" diff --cached --name-only -z --no-renames | _nul_lines)"
if [[ -n "$staged" ]]; then ok "staged $(wc -l <<<"$staged") path(s)"; else bad "nothing staged"; fi

if [[ -n "$paths" ]]; then
  want="$(sed '/^$/d' <<<"$paths" | LC_ALL=C sort -u)"
  if [[ "$staged" == "$want" ]]; then ok "staged set matches --paths"; else
    extra="$(comm -23 <(echo "$staged") <(echo "$want") | tr '\n' ' ')"
    miss="$(comm -13 <(echo "$staged") <(echo "$want") | tr '\n' ' ')"
    bad "staged set differs; extra: ${extra:-none}; missing: ${miss:-none}"
  fi
fi

if [[ -n "$staged" ]]; then
  # Untracked + unstaged; also any staged-deletion path still on disk (even if ignored).
  dirty="$(
    {
      git -C "$wt" diff --name-only -z --no-renames
      git -C "$wt" ls-files -z --others --exclude-standard
      while IFS= read -r -d '' p; do
        if [[ -e "$wt/$p" || -L "$wt/$p" ]]; then printf '%s\0' "$p"; fi
      done < <(git -C "$wt" diff --cached --name-only -z --diff-filter=D --no-renames)
    } | _nul_lines
  )"
  partial="$(comm -12 <(echo "$staged") <(echo "$dirty") | tr '\n' ' ')"
  if [[ -z "$partial" ]]; then ok "no unstaged edits on staged paths"; else bad "staged paths also have unstaged edits: $partial"; fi
fi

if git -C "$wt" diff --cached --check >/dev/null 2>&1; then ok "git diff --cached --check"; else bad "git diff --cached --check (whitespace errors)"; fi

if [[ -n "$evidence" ]]; then
  if [[ ! -r "$evidence" ]]; then bad "evidence not readable: $evidence"
  elif reason="$(head -n 1 "$evidence" | node -e '
      const keys = ["goal","owner","success","evidence_path","approval","return"];
      let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
        let o; try { o = JSON.parse(s); } catch { console.log("line 1 is not JSON"); process.exit(1); }
        if (!o || typeof o !== "object" || Array.isArray(o)) { console.log("line 1 is not a JSON object"); process.exit(1); }
        const miss = keys.filter(k => !(k in o));
        if (miss.length) { console.log("header missing keys: " + miss.join(",")); process.exit(1); }
      });')"; then ok "evidence header $evidence"
  else bad "evidence $evidence: $reason"; fi
fi

if [[ "$ci" -eq 1 ]]; then
  if [[ ! -x "$wt/scripts/ci-mimic.sh" ]]; then bad "ci-mimic missing in $wt"
  elif bash "$wt/scripts/ci-mimic.sh" >/dev/null 2>&1; then ok "ci-mimic"
  else bad "ci-mimic (rerun: bash scripts/ci-mimic.sh)"; fi
fi

if [[ "$fail" -eq 0 ]]; then echo "verify-lane: PASS"; else echo "verify-lane: FAIL"; fi
exit "$fail"
