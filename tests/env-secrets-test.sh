#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
FIXTURE="$ROOT/tests/fixtures/secrets.fixture.env"

THUNDERSTONE_SECRETS_BACKEND=fixture \
  THUNDERSTONE_SECRETS_FIXTURE="$FIXTURE" \
  node scripts/env-run.mjs node -e 'if(process.env.FIXTURE_SECRET!=="from-fixture")process.exit(1)'

CLAN_NAME=override \
  THUNDERSTONE_SECRETS_BACKEND=fixture \
  THUNDERSTONE_SECRETS_FIXTURE="$FIXTURE" \
  node scripts/env-run.mjs node -e 'if(process.env.CLAN_NAME!=="override")process.exit(1)'

THUNDERSTONE_SECRETS_BACKEND=off node scripts/env-run.mjs node -e 'if(process.env.FIXTURE_SECRET)process.exit(1)'

node scripts/env-doctor.mjs >/dev/null

echo "env-secrets tests passed."
