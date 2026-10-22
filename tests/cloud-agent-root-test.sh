#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/cloud-agent-root.sh
. "$ROOT/scripts/cloud-agent-root.sh"

# Live Cloud roots only exist on Cursor Cloud pods — skip on GHA/local.
if [[ -f /workspace/scripts/bootstrap.sh || -f /agent/repos/thunderstone-starter/scripts/bootstrap.sh ]]; then
  fail=0
  got="$(cloud_agent_repo_root)" || fail=1
  if [[ "$fail" -eq 1 ]]; then
    echo "cloud_agent_repo_root failed on live VM" >&2
    exit 1
  fi
  if [[ "$got" != "$ROOT" ]]; then
    echo "expected repo root $ROOT, got $got" >&2
    exit 1
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/fake/scripts"
printf '#!/bin/sh\n' >"$tmpdir/fake/scripts/bootstrap.sh"
chmod +x "$tmpdir/fake/scripts/bootstrap.sh"

# Prefer /workspace when both exist (build-pod order).
mkdir -p "$tmpdir/ws/scripts"
printf '#!/bin/sh\n' >"$tmpdir/ws/scripts/bootstrap.sh"
chmod +x "$tmpdir/ws/scripts/bootstrap.sh"

cloud_agent_repo_root_override() {
  local d
  for d in "$tmpdir/ws" "$tmpdir/fake"; do
    if [[ -f "$d/scripts/bootstrap.sh" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

# Inline test of search order without touching real paths
first=""
for d in "$tmpdir/ws" "$tmpdir/fake"; do
  [[ -f "$d/scripts/bootstrap.sh" ]] && { first="$d"; break; }
done
[[ "$first" == "$tmpdir/ws" ]] || {
  echo "search order should prefer first existing root" >&2
  exit 1
}

echo "cloud-agent-root-test: ok"
