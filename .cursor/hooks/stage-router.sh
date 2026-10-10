#!/usr/bin/env bash
# Stage-aware advisory router for Cursor sessionStart (read-only).
set -euo pipefail

emit_empty() {
  printf '{}\n'
}

emit_stage() {
  local stage="$1"
  local reason="$2"
  reason="${reason//\\/\\\\}"
  reason="${reason//\"/\\\"}"
  printf '{"additional_context":"STAGE=%s reason=%s"}\n' "$stage" "$reason"
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  emit_empty
  exit 0
fi
cd "$repo_root"

porcelain="$(git status --porcelain 2>/dev/null || true)"
branch="$(git branch --show-current 2>/dev/null || true)"
changed_paths="$(
  {
    git diff --name-only HEAD 2>/dev/null || true
    git diff --name-only --cached 2>/dev/null || true
    printf '%s' "$porcelain" | awk '{print $2}'
  } | sed '/^$/d' | sort -u
)"

ahead=0
behind=0
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -n "$upstream" ]; then
  counts="$(git rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || true)"
  if [ -n "$counts" ]; then
    IFS=$'\t' read -r behind ahead <<<"$counts"
  fi
elif [ -n "$branch" ] && git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
  counts="$(git rev-list --left-right --count "origin/${branch}...HEAD" 2>/dev/null || true)"
  if [ -n "$counts" ]; then
    IFS=$'\t' read -r behind ahead <<<"$counts"
  fi
fi

default_branch="main"
origin_head="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
if [ -n "$origin_head" ]; then
  default_branch="${origin_head#origin/}"
fi

dirty=0
if [ -n "$porcelain" ]; then
  dirty=1
fi

gh_ok=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh_ok=1
fi

monitor_reason=""
triage_reason=""
build_reason=""

if [ "$gh_ok" -eq 1 ]; then
  run_json="$(gh run list --branch "$default_branch" -L1 --json conclusion,status 2>/dev/null || true)"
  run_conclusion="$(printf '%s' "${run_json:-[]}" | jq -r '.[0].conclusion // empty' 2>/dev/null || true)"
  if [ "$run_conclusion" = "failure" ]; then
    monitor_reason="default-branch CI run failed"
  fi

  for label in incident regression p0; do
    issue_json="$(gh issue list --label "$label" --state open --limit 1 --json number 2>/dev/null || true)"
    issue_n="$(printf '%s' "${issue_json:-[]}" | jq -r 'length' 2>/dev/null || echo 0)"
    if [ "${issue_n:-0}" -gt 0 ] 2>/dev/null; then
      monitor_reason="open issue labeled ${label}"
      break
    fi
  done
fi

diff_check_failed=0
if ! git diff --check >/dev/null 2>&1; then
  diff_check_failed=1
fi

secret_or_abs_in_diff=0
if [ "$dirty" -eq 1 ]; then
  diff_text="$(git diff HEAD 2>/dev/null || true)"
  if printf '%s' "$diff_text" | grep -Eq '(^|[[:space:]=(:\`"\x27])/([hH]ome|Users|root)/[A-Za-z0-9_.-]+|(^|[^A-Za-z])[A-Za-z]:\\[A-Za-z0-9_.-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}'; then
    secret_or_abs_in_diff=1
  fi
fi

tests_known_red=0
if [ "$dirty" -eq 1 ] && [ -f .state/tests-known-red ]; then
  tests_known_red=1
fi

touches_sensitive_paths=0
if [ "$dirty" -eq 1 ] && [ -n "$changed_paths" ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      .github/workflows/*|scripts/*|.husky/*) touches_sensitive_paths=1 ;;
      package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|Gemfile.lock|poetry.lock|Cargo.lock|go.sum)
        touches_sensitive_paths=1
        ;;
    esac
  done <<<"$changed_paths"
fi

pr_failing_checks=0
pr_approved_green=0
has_open_pr=0
if [ "$gh_ok" -eq 1 ] && [ -n "$branch" ]; then
  pr_json="$(gh pr list --head "$branch" --state open --json number,reviewDecision,statusCheckRollup 2>/dev/null || true)"
  if [ -n "$pr_json" ] && [ "$pr_json" != "[]" ]; then
    has_open_pr=1
    pr_eval="$(printf '%s' "$pr_json" | jq -r '
      .[0] as $pr |
      if $pr == null then "none"
      else
        ($pr.statusCheckRollup // []) as $r |
        if any($r[]?; ((.conclusion // .state // "") | test("fail|cancel|timed_?out|action_required"; "i"))) then "failing"
        elif $pr.reviewDecision == "APPROVED" and ($r | length) > 0 and all($r[]?; ((.conclusion // .state // "") | ascii_downcase | IN("success", "neutral", "skipped"))) then "approved_green"
        else "open" end
      end
    ' 2>/dev/null || true)"
    case "$pr_eval" in
      failing) pr_failing_checks=1 ;;
      approved_green) pr_approved_green=1 ;;
    esac
  fi
fi

docs_only_dirty=0
if [ "$dirty" -eq 1 ] && [ -n "$changed_paths" ]; then
  docs_only_dirty=1
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      *.md) ;;
      *) docs_only_dirty=0; break ;;
    esac
  done <<<"$changed_paths"
fi

if [ "$dirty" -eq 1 ]; then
  if [ "$diff_check_failed" -eq 1 ]; then
    triage_reason="dirty tree and git diff --check failed"
  elif [ "$secret_or_abs_in_diff" -eq 1 ]; then
    triage_reason="dirty tree and diff matches secret or absolute-path pattern"
  elif [ "$tests_known_red" -eq 1 ]; then
    triage_reason="dirty tree and tests known red (.state/tests-known-red)"
  fi
fi
if [ -z "$triage_reason" ] && [ "$touches_sensitive_paths" -eq 1 ]; then
  triage_reason="changes touch workflows, scripts, hooks or lockfiles"
fi
if [ -z "$triage_reason" ] && [ "$pr_failing_checks" -eq 1 ]; then
  triage_reason="open PR has failing checks"
fi

if [ "$pr_approved_green" -eq 1 ]; then
  build_reason="open PR approved with green checks"
elif [ "$docs_only_dirty" -eq 1 ]; then
  build_reason="docs-only changes"
elif [ "$dirty" -eq 1 ] && [ -z "$triage_reason" ]; then
  build_reason="dirty tree without triage signals"
elif [ "$dirty" -eq 0 ] && [ "${ahead:-0}" -gt 0 ] && [ "$has_open_pr" -eq 0 ]; then
  build_reason="commits ahead of remote with no open PR"
elif [ "$dirty" -eq 0 ] && [ "${ahead:-0}" -eq 0 ] && [ "${behind:-0}" -eq 0 ] \
  && [ "$branch" = "$default_branch" ]; then
  build_reason="clean synced tree; consider claiming a Project #2 item"
fi

if [ -n "$monitor_reason" ]; then
  emit_stage Monitor "$monitor_reason"
  exit 0
fi
if [ -n "$triage_reason" ]; then
  emit_stage Triage "$triage_reason"
  exit 0
fi
if [ -n "$build_reason" ]; then
  emit_stage Build "$build_reason"
  exit 0
fi

emit_empty
