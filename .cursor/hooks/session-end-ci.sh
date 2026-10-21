#!/usr/bin/env bash
# sessionEnd: detach local npm test when the worktree fingerprint changes.
set -euo pipefail

if [ ! -t 0 ]; then
  cat >/dev/null || true
fi

emit_empty() {
  printf '{}\n'
}

if [ "${SESSION_CI_DISABLE:-}" = "1" ]; then
  emit_empty
  exit 0
fi

repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo" ]; then
  emit_empty
  exit 0
fi
cd "$repo"

state_dir=".state/session-ci"
mkdir -p "$state_dir"

lock="${state_dir}/lock"
if [ -f "$lock" ]; then
  pid="$(tr -cd '0-9' <"$lock" || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    emit_empty
    exit 0
  fi
fi

fingerprint="$(
  {
    git status --porcelain
    git rev-parse HEAD
  } | { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; } | awk '{print $1}'
)"
stored="${state_dir}/fingerprint"
if [ -f "$stored" ] && [ "$(tr -d '[:space:]' <"$stored")" = "$fingerprint" ]; then
  emit_empty
  exit 0
fi

printf '%s\n' "$fingerprint" >"$stored"

cat >"${state_dir}/runner.sh" <<'EOF'
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."
echo $$ >.state/session-ci/lock
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
head="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
timeout_sec="${SESSION_CI_TIMEOUT:-600}"
set +e
if command -v timeout >/dev/null 2>&1; then
  timeout "$timeout_sec" npm test >.state/session-ci/last.log 2>&1
else
  npm test >.state/session-ci/last.log 2>&1
fi
code=$?
set -e
finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_CI_HEAD="$head" \
SESSION_CI_STARTED="$started" \
SESSION_CI_FINISHED="$finished" \
SESSION_CI_EXIT="$code" \
node -e '
const fs = require("fs");
const o = {
  head: process.env.SESSION_CI_HEAD || "",
  started: process.env.SESSION_CI_STARTED || "",
  finished: process.env.SESSION_CI_FINISHED || "",
  exit: Number(process.env.SESSION_CI_EXIT || "1"),
  log: ".state/session-ci/last.log"
};
fs.writeFileSync(".state/session-ci/last.json", JSON.stringify(o) + "\n");
'
rm -f .state/session-ci/lock
EOF
chmod +x "${state_dir}/runner.sh"

# Run like CI: a BASH_ENV startup file must not alter PATH for the detached test.
unset BASH_ENV
if command -v setsid >/dev/null 2>&1; then
  setsid bash "${state_dir}/runner.sh" </dev/null >"${state_dir}/detach.out" 2>&1 &
else
  nohup bash "${state_dir}/runner.sh" </dev/null >"${state_dir}/detach.out" 2>&1 &
fi
echo $! >"$lock"

emit_empty
exit 0
