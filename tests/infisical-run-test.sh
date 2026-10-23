#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/infisical" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" == "fixture-secret" ]] || exit 1
printf '%s\n' "$@" >"$INFISICAL_TEST_ARGS_FILE"
while (($#)); do
  if [[ "$1" == "--" ]]; then
    shift
    export XAI_API_KEY="fixture-provider"
    exec "$@"
  fi
  shift
done
exit 1
EOF
chmod +x "$tmp/bin/infisical"

output="$(
  PATH="$tmp/bin:$PATH" \
    INFISICAL_TEST_ARGS_FILE="$tmp/args" \
    INFISICAL_PROJECT_ID="fixture-project" \
    INFISICAL_ENVIRONMENT="dev" \
    INFISICAL_SECRET_PATH="/coding" \
    INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="fixture-client-id" \
    INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="fixture-secret" \
    bash scripts/infisical-run.sh -- bash -c '
      [[ "${XAI_API_KEY:-}" == "fixture-provider" ]]
      [[ -z "${INFISICAL_TOKEN:-}" ]]
      [[ -z "${INFISICAL_UNIVERSAL_AUTH_ACCESS_TOKEN:-}" ]]
      [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" ]]
      [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" ]]
      echo "injected"
    '
)"
[[ "$output" == "injected" ]] || { echo "child output did not match"; exit 1; }
grep -qF -- "--projectId=fixture-project" "$tmp/args"
grep -qF -- "--env=dev" "$tmp/args"
grep -qF -- "--path=/coding" "$tmp/args"
if grep -qF "fixture-secret" "$tmp/args"; then
  echo "machine credential appeared in CLI arguments" >&2
  exit 1
fi

if PATH="$tmp/bin:$PATH" \
  INFISICAL_PROJECT_ID="fixture-project" \
  INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="fixture-client-id" \
  bash scripts/infisical-run.sh -- true 2>"$tmp/error"; then
  echo "expected incomplete machine credentials to fail" >&2
  exit 1
fi
grep -qF "Set both Universal Auth client ID and client secret" "$tmp/error"

echo "infisical-run tests passed."
