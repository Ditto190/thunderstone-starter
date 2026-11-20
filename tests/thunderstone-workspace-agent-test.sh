#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/thunderstone-workspace.sh"
STUB="$(mktemp -d)"
trap 'rm -rf "$STUB"' EXIT
mkdir -p "$STUB/ops/bridge"
cat >"$STUB/agent" <<'EOF'
#!/bin/sh
if [ "${1:-}" = persist ]; then
  printf '%s\n' agent-persist
  exit 0
fi
printf 'agent %s\n' "$*"
EOF
chmod +x "$STUB/agent"

env_common() {
  env -i HOME="${HOME:-/tmp}" USER="${USER:-box}" PATH="$STUB:/usr/bin:/bin" \
    THUNDERSTONE_OPERATIONAL_ROOT="$STUB/ops" "$@"
}

out="$(
  printf 'source "%s"\nagent\nexit\n' "$LIB" | env_common \
    script -qfec 'bash --norc --noprofile -i' /dev/null 2>/dev/null | tr -d '\r'
)"
grep -q agent-persist <<<"$out" || { echo "expected persist branch, got: $out"; exit 1; }

out="$(env_common bash --norc --noprofile <<EOS
# shellcheck disable=SC1090
source "$LIB"
TS_NO_PERSIST=1 agent --version
EOS
)"
grep -q 'agent --version' <<<"$out" || { echo "TS_NO_PERSIST bypass failed: $out"; exit 1; }

echo "thunderstone-workspace-agent-test passed"