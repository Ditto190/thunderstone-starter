#!/usr/bin/env bash
# doctor.sh prepends "$HOME/.local/bin". A fake node there covers both majors
# without changing the real toolchain.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.local/bin"
cat >"$TMP/.local/bin/node" <<'EOF'
#!/bin/sh
major="${FAKE_NODE_MAJOR:?}"
if [ "${1:-}" = "-p" ]; then
  printf '%s\n' "$major"
else
  printf 'v%s.0.0\n' "$major"
fi
EOF
chmod +x "$TMP/.local/bin/node"

run_doctor() {
  HOME="$TMP" FAKE_NODE_MAJOR="$1" bash "$ROOT/scripts/doctor.sh"
}

ok_out="$(run_doctor 22)"
printf '%s\n' "$ok_out" | grep -q 'OK node-major 22'

set +e
bad_out="$(run_doctor 21)"
bad_status=$?
set -e
printf '%s\n' "$bad_out" | grep -q 'MISSING node-major>=22'
test "$bad_status" -ne 0

echo "Doctor node-major tests passed."
