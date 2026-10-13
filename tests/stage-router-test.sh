#!/usr/bin/env bash
set -euo pipefail

# Husky exports GIT_DIR. Leaving it set makes git init rewrite the parent
# repo and makes a temp directory look like a checkout.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="${ROOT}/.cursor/hooks/stage-router.sh"
TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

failures=0

assert_output() {
  local name="$1"
  local expected_substr="$2"
  local out="$3"
  if ! grep -qF "$expected_substr" <<<"$out"; then
    echo "stage-router test FAIL: $name" >&2
    echo "  expected substring: $expected_substr" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

assert_exact() {
  local name="$1"
  local expected="$2"
  local out="$3"
  if [ "$out" != "$expected" ]; then
    echo "stage-router test FAIL: $name" >&2
    echo "  expected: $expected" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

assert_valid_json() {
  local name="$1"
  local out="$2"
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    echo "stage-router test FAIL: $name (invalid JSON)" >&2
    echo "  got: $out" >&2
    failures=1
  fi
}

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -b main
    git config user.email "Ditto190@users.noreply.github.com"
    git config user.name "Ditto190"
    echo "seed" >README.md
    git add README.md
    git commit -m "chore: seed"
  )
}

run_router() {
  local dir="$1"
  local mock_mode="${2:-}"
  (
    cd "$dir"
    export PATH="${MOCK_BIN}:${PATH}"
    export STAGE_ROUTER_MOCK_GH="$mock_mode"
    bash "$ROUTER"
  )
}

mock_gh_dir="$(mktemp -d)"
cat >"${mock_gh_dir}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${STAGE_ROUTER_MOCK_GH:-}" in
  monitor_ci_fail)
    if [[ "$*" == *"run list"* ]]; then
      printf '%s\n' '[{"conclusion":"failure","status":"completed"}]'
      exit 0
    fi
    ;;
  monitor_p0)
    if [[ "$*" == *"issue list"* ]] && [[ "$*" == *"label p0"* ]]; then
      printf '%s\n' '[{"number":99}]'
      exit 0
    fi
    if [[ "$*" == *"run list"* ]]; then
      printf '%s\n' '[{"conclusion":"success","status":"completed"}]'
      exit 0
    fi
    ;;
  monitor_deploy_fail)
    if [[ "$*" == *"repo view"* ]]; then
      printf '%s\n' 'acme/widget'
      exit 0
    fi
    if [[ "$*" == *"deployments/42/statuses"* ]]; then
      printf '%s\n' 'failure'
      exit 0
    fi
    if [[ "$*" == *"deployments"* ]] && [[ "$*" != *"statuses"* ]]; then
      printf '%s\n' '42'
      exit 0
    fi
    if [[ "$*" == *"run list"* ]]; then
      printf '%s\n' '[{"conclusion":"success","status":"completed"}]'
      exit 0
    fi
    ;;
  triage_pr_fail)
    if [[ "$*" == *"pr list"* ]]; then
      printf '%s\n' '[{"number":1,"reviewDecision":"","statusCheckRollup":[{"conclusion":"FAILURE"}]}]'
      exit 0
    fi
    if [[ "$*" == *"run list"* ]]; then
      printf '%s\n' '[{"conclusion":"success","status":"completed"}]'
      exit 0
    fi
    ;;
  build_approved)
    if [[ "$*" == *"pr list"* ]]; then
      printf '%s\n' '[{"number":2,"reviewDecision":"APPROVED","statusCheckRollup":[{"conclusion":"SUCCESS"}]}]'
      exit 0
    fi
    if [[ "$*" == *"run list"* ]]; then
      printf '%s\n' '[{"conclusion":"success","status":"completed"}]'
      exit 0
    fi
    ;;
  green_clean)
    if [[ "$*" == *"run list"* ]]; then
      printf '%s\n' '[{"conclusion":"success","status":"completed"}]'
      exit 0
    fi
    if [[ "$*" == *"pr list"* ]]; then
      printf '%s\n' '[]'
      exit 0
    fi
    if [[ "$*" == *"repo view"* ]]; then
      printf '%s\n' 'acme/widget'
      exit 0
    fi
    if [[ "$*" == *"deployments"* ]]; then
      printf '\n'
      exit 0
    fi
    ;;
esac
if [[ "$*" == *"auth status"* ]]; then exit 0; fi
if [[ "$*" == *"issue list"* ]]; then printf '[]\n'; exit 0; fi
if [[ "$*" == *"pr list"* ]]; then printf '[]\n'; exit 0; fi
if [[ "$*" == *"run list"* ]]; then printf '[]\n'; exit 0; fi
if [[ "$*" == *"repo view"* ]]; then printf 'acme/widget\n'; exit 0; fi
if [[ "$*" == *"api"* ]]; then printf '\n'; exit 0; fi
exit 0
EOF
chmod +x "${mock_gh_dir}/gh"

MOCK_BIN="$mock_gh_dir"

# Non-git directory
nogit="${TMP_BASE}/not-a-repo"
mkdir -p "$nogit"
out="$(run_router "$nogit")"
assert_exact "non-git" '{}' "$out"
assert_valid_json "non-git-json" "$out"

# Build: dirty tree without triage signals
repo="${TMP_BASE}/build-dirty"
init_repo "$repo"
echo "x" >>"${repo}/notes.txt"
out="$(run_router "$repo")"
assert_output "build-dirty" 'STAGE=Build' "$out"
assert_valid_json "build-dirty-json" "$out"

# Triage: diff --check on tracked file (trailing whitespace)
repo="${TMP_BASE}/triage-diffcheck"
init_repo "$repo"
printf 'line \n' >>"${repo}/README.md"
out="$(run_router "$repo")"
assert_output "triage-diffcheck" 'STAGE=Triage' "$out"

# Triage: diff --check on untracked file
repo="${TMP_BASE}/triage-diffcheck-untracked"
init_repo "$repo"
printf 'trail \n' >"${repo}/new-file.txt"
out="$(run_router "$repo")"
assert_output "triage-diffcheck-untracked" 'STAGE=Triage' "$out"

# Triage: secret pattern in tracked diff
repo="${TMP_BASE}/triage-secret"
init_repo "$repo"
printf 'token=ghp_%s\n' "$(printf 'a%.0s' {1..32})" >>"${repo}/README.md"
out="$(run_router "$repo")"
assert_output "triage-secret" 'STAGE=Triage' "$out"

# Triage: secret in untracked file
repo="${TMP_BASE}/triage-secret-untracked"
init_repo "$repo"
printf 'token=ghp_%s\n' "$(printf 'b%.0s' {1..32})" >"${repo}/leak.txt"
out="$(run_router "$repo")"
assert_output "triage-secret-untracked" 'STAGE=Triage' "$out"

# False positive: foox/home/dt must not triage on secret/abs-path rule
repo="${TMP_BASE}/no-false-abs"
init_repo "$repo"
printf 'foox/home/dt\n' >"${repo}/benign.txt"
out="$(run_router "$repo")"
assert_output "no-false-abs" 'STAGE=Build' "$out"

# Triage: scripts path
repo="${TMP_BASE}/triage-scripts"
init_repo "$repo"
mkdir -p "${repo}/scripts"
echo "touch" >>"${repo}/scripts/a.sh"
out="$(run_router "$repo")"
assert_output "triage-scripts" 'STAGE=Triage' "$out"

# Triage: .cursor/hooks path
repo="${TMP_BASE}/triage-cursor-hooks"
init_repo "$repo"
mkdir -p "${repo}/.cursor/hooks"
echo "# x" >>"${repo}/.cursor/hooks/extra.sh"
out="$(run_router "$repo")"
assert_output "triage-cursor-hooks" 'STAGE=Triage' "$out"

# Triage: path with spaces (untracked)
repo="${TMP_BASE}/triage-space-path"
init_repo "$repo"
printf 'x' >"${repo}/my notes.txt"
out="$(run_router "$repo")"
assert_output "triage-space-path" 'STAGE=Build' "$out"

# Triage: tests known red marker
repo="${TMP_BASE}/triage-tests-red"
init_repo "$repo"
mkdir -p "${repo}/.state"
touch "${repo}/.state/tests-known-red"
echo "y" >>"${repo}/README.md"
out="$(run_router "$repo")"
assert_output "triage-tests-red" 'STAGE=Triage' "$out"

# Build: docs-only
repo="${TMP_BASE}/build-docs"
init_repo "$repo"
echo "docs" >>"${repo}/CHANGELOG.md"
out="$(run_router "$repo")"
assert_output "build-docs" 'STAGE=Build' "$out"
assert_output "build-docs-reason" 'docs-only' "$out"

# Build: ahead with no PR
repo="${TMP_BASE}/build-ahead"
init_repo "$repo"
(
  cd "$repo"
  git remote add origin "$repo"
  git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
  echo "more" >>README.md
  git add README.md
  git commit -m "feat: local only"
  git branch --set-upstream-to origin/main
)
out="$(run_router "$repo" green_clean)"
assert_output "build-ahead" 'STAGE=Build' "$out"

# Build: clean synced project hint (default branch)
repo="${TMP_BASE}/build-synced"
init_repo "$repo"
out="$(run_router "$repo" green_clean)"
assert_output "build-synced" 'Project #2' "$out"

# Monitor: CI fail on default branch
repo="${TMP_BASE}/monitor-ci"
init_repo "$repo"
out="$(run_router "$repo" monitor_ci_fail)"
assert_output "monitor-ci" 'STAGE=Monitor' "$out"

# Monitor: p0 label
repo="${TMP_BASE}/monitor-p0"
init_repo "$repo"
out="$(run_router "$repo" monitor_p0)"
assert_output "monitor-p0" 'STAGE=Monitor' "$out"

# Monitor: failed deployment
repo="${TMP_BASE}/monitor-deploy"
init_repo "$repo"
out="$(run_router "$repo" monitor_deploy_fail)"
assert_output "monitor-deploy" 'STAGE=Monitor' "$out"
assert_output "monitor-deploy-reason" 'deployment failed' "$out"

# Precedence: Monitor beats Triage on dirty tree + CI fail
repo="${TMP_BASE}/precedence-monitor"
init_repo "$repo"
printf 'token=ghp_%s\n' "$(printf 'c%.0s' {1..32})" >>"${repo}/README.md"
out="$(run_router "$repo" monitor_ci_fail)"
assert_output "precedence-monitor" 'STAGE=Monitor' "$out"

# Triage: PR failing checks (clean tree)
repo="${TMP_BASE}/triage-pr-fail"
init_repo "$repo"
git -C "$repo" checkout -b feat/x
out="$(run_router "$repo" triage_pr_fail)"
assert_output "triage-pr-fail" 'STAGE=Triage' "$out"

# Build: approved green PR
repo="${TMP_BASE}/build-approved"
init_repo "$repo"
git -C "$repo" checkout -b feat/y
out="$(run_router "$repo" build_approved)"
assert_output "build-approved" 'STAGE=Build' "$out"

# Green + clean idle on a synced feature branch (no stage advisory)
repo="${TMP_BASE}/green-idle2"
init_repo "$repo"
git -C "$repo" checkout -b feat/wait
(
  cd "$repo"
  git remote add origin "$repo"
  git update-ref refs/remotes/origin/feat/wait HEAD
  git config branch.feat/wait.remote origin
  git config branch.feat/wait.merge refs/heads/feat/wait
)
out="$(run_router "$repo" green_clean)"
assert_exact "green-clean-idle" '{}' "$out"
assert_valid_json "green-clean-json" "$out"

if [ "$failures" -ne 0 ]; then
  echo "stage-router tests failed" >&2
  exit 1
fi
echo "stage-router fixture tests passed."
