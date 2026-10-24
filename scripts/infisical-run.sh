#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

usage() {
  echo "Usage: bash scripts/infisical-run.sh -- <command> [args...]" >&2
  exit 2
}

[[ $# -gt 1 && "$1" == "--" ]] || usage
shift

command -v infisical >/dev/null || {
  echo "Infisical CLI not found. Install it from https://infisical.com/docs/cli/usage." >&2
  exit 1
}
command -v env >/dev/null || {
  echo "env command not found; install coreutils or BusyBox." >&2
  exit 1
}

: "${INFISICAL_PROJECT_ID:?Set INFISICAL_PROJECT_ID to the Infisical project ID}"
environment="${INFISICAL_ENVIRONMENT:-dev}"
secret_path="${INFISICAL_SECRET_PATH:-/coding}"

client_id="${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}"
client_secret="${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}"
if [[ -n "$client_id" && -z "$client_secret" ]] || [[ -z "$client_id" && -n "$client_secret" ]]; then
  echo "Set both Universal Auth client ID and client secret, or neither." >&2
  exit 2
fi

exec infisical sm run \
  --projectId="$INFISICAL_PROJECT_ID" \
  --env="$environment" \
  --path="$secret_path" \
  -- env \
    -u INFISICAL_TOKEN \
    -u INFISICAL_UNIVERSAL_AUTH_ACCESS_TOKEN \
    -u INFISICAL_UNIVERSAL_AUTH_CLIENT_ID \
    -u INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET \
    -- "$@"
