#!/usr/bin/env bash
# Stage-aware advisory router for Cursor sessionStart (read-only).
set -euo pipefail

STAGE_ROUTER_BUDGET_SEC="${STAGE_ROUTER_BUDGET_SEC:-4}"
stage_router_start="$SECONDS"

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

budget_remaining_sec() {
  local elapsed=$((SECONDS - stage_router_start))
  echo $((STAGE_ROUTER_BUDGET_SEC - elapsed))
}

gh_timed_capture() {
  local per_call_sec="$1"
  shift
  local remain
  remain="$(budget_remaining_sec)"
  if [ "${remain:-0}" -le 0 ]; then
    return 124
  fi
  if [ "$per_call_sec" -gt "$remain" ]; then
    per_call_sec="$remain"
  fi
  if ! command -v timeout >/dev/null 2>&1; then
    gh "$@" 2>/dev/null
    return $?
  fi
  timeout "$per_call_sec" gh "$@" 2>/dev/null
}

collect_scan_text() {
  local path
  {
    git diff HEAD 2>/dev/null || true
    git diff --cached 2>/dev/null || true
  }
  while IFS= read -r -d '' path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    git diff --no-index -- /dev/null "$path" 2>/dev/null || true
  done < <(git ls-files -o --exclude-standard -z 2>/dev/null || true)
}

diff_check_includes_untracked() {
  if ! git diff --check >/dev/null 2>&1; then
    return 1
  fi
  if ! git diff --check --cached >/dev/null 2>&1; then
    return 1
  fi
  local path out
  while IFS= read -r -d '' path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    out="$(git diff --no-index --check -- /dev/null "$path" 2>&1 || true)"
    if printf '%s' "$out" | grep -Eq 'trailing whitespace|space before tab|conflict marker|new blank line at EOF'; then
      return 1
    fi
  done < <(git ls-files -o --exclude-standard -z 2>/dev/null || true)
  return 0
}

matches_secret_or_abs_path() {
  local text="$1"
  printf '%s' "$text" | grep -Eq \
    '(^|[^A-Za-z0-9_.-])/(home|Users|root)/[A-Za-z0-9_.-]+|(^|[^A-Za-z])[A-Za-z]:\\[A-Za-z0-9_.-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}'
}

collect_changed_paths_z() {
  local -n _out_var=$1
  local -A seen=()
  local path
  _out_var=()
  while IFS= read -r -d '' path; do
    [ -n "$path" ] || continue
    seen["$path"]=1
  done < <(
    {
      git diff --name-only -z HEAD 2>/dev/null || true
      git diff --name-only -z --cached 2>/dev/null || true
      git ls-files -o --exclude-standard -z 2>/dev/null || true
    }
  )
  for path in "${!seen[@]}"; do
    _out_var+=("$path")
  done
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  emit_empty
  exit 0
fi
cd "$repo_root"

porcelain="$(git status --porcelain 2>/dev/null || true)"
branch="$(git branch --show-current 2>/dev/null || true)"
changed_paths=()
collect_changed_paths_z changed_paths

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
if command -v gh >/dev/null 2>&1 && gh_timed_capture 1 auth status >/dev/null 2>&1; then
  gh_ok=1
fi

monitor_reason=""
triage_reason=""
build_reason=""

if [ "$gh_ok" -eq 1 ] && [ "$(budget_remaining_sec)" -gt 0 ]; then
  run_json="$(gh_timed_capture 1 run list --branch "$default_branch" -L1 --json conclusion,status || true)"
  run_conclusion="$(printf '%s' "${run_json:-[]}" | jq -r '.[0].conclusion // empty' 2>/dev/null || true)"
  if [ "$run_conclusion" = "failure" ]; then
    monitor_reason="default-branch CI run failed"
  fi
fi

if [ "$gh_ok" -eq 1 ] && [ -z "$monitor_reason" ] && [ "$(budget_remaining_sec)" -gt 0 ]; then
  router_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    issue_json="$(gh_timed_capture 1 issue list --label "$label" --state open --limit 1 --json number || true)"
    issue_n="$(printf '%s' "${issue_json:-[]}" | jq -r 'length' 2>/dev/null || echo 0)"
    if [ "${issue_n:-0}" -gt 0 ] 2>/dev/null; then
      monitor_reason="open issue labeled ${label}"
      break
    fi
  done < <(node "$router_root/scripts/clan.mjs" labels --signal monitor 2>/dev/null || true)
fi

if [ "$gh_ok" -eq 1 ] && [ -z "$monitor_reason" ] && [ "$(budget_remaining_sec)" -gt 0 ]; then
  repo_slug="$(gh_timed_capture 1 repo view --json nameWithOwner --jq .nameWithOwner || true)"
  if [ -n "$repo_slug" ]; then
    deploy_id="$(gh_timed_capture 1 api "repos/${repo_slug}/deployments" --jq '.[0].id // empty' || true)"
    if [ -n "$deploy_id" ]; then
      deploy_state="$(gh_timed_capture 1 api "repos/${repo_slug}/deployments/${deploy_id}/statuses" --jq '.[0].state // empty' || true)"
      if [ "$deploy_state" = "failure" ] || [ "$deploy_state" = "error" ]; then
        monitor_reason="latest deployment failed"
      fi
    fi
  fi
fi

diff_check_failed=0
if ! diff_check_includes_untracked; then
  diff_check_failed=1
fi

secret_or_abs_in_diff=0
if [ "$dirty" -eq 1 ]; then
  scan_text="$(collect_scan_text)"
  if matches_secret_or_abs_path "$scan_text"; then
    secret_or_abs_in_diff=1
  fi
fi

tests_known_red=0
if [ "$dirty" -eq 1 ] && [ -f .state/tests-known-red ]; then
  tests_known_red=1
fi

touches_sensitive_paths=0
if [ "$dirty" -eq 1 ] && [ "${#changed_paths[@]}" -gt 0 ]; then
  for path in "${changed_paths[@]}"; do
    [ -n "$path" ] || continue
    case "$path" in
      .github/workflows/*|scripts/*|.husky/*|.cursor/hooks/*) touches_sensitive_paths=1 ;;
      package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|Gemfile.lock|poetry.lock|Cargo.lock|go.sum)
        touches_sensitive_paths=1
        ;;
    esac
  done
fi

pr_failing_checks=0
pr_approved_green=0
has_open_pr=0
if [ "$gh_ok" -eq 1 ] && [ -n "$branch" ] && [ "$(budget_remaining_sec)" -gt 0 ]; then
  pr_json="$(gh_timed_capture 1 pr list --head "$branch" --state open --json number,reviewDecision,statusCheckRollup || true)"
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
if [ "$dirty" -eq 1 ] && [ "${#changed_paths[@]}" -gt 0 ]; then
  docs_only_dirty=1
  for path in "${changed_paths[@]}"; do
    [ -n "$path" ] || continue
    case "$path" in
      *.md) ;;
      *) docs_only_dirty=0; break ;;
    esac
  done
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
