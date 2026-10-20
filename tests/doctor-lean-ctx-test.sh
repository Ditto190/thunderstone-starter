#!/usr/bin/env bash
# doctor.sh lists lean-ctx as optional. Required-tool misses must not hide that line.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$(bash "$ROOT/scripts/doctor.sh" || true)"

if printf '%s\n' "$out" | grep -qx 'MISSING lean-ctx'; then
  echo "doctor test FAIL: lean-ctx is required" >&2
  exit 1
fi

if ! printf '%s\n' "$out" | grep -Eq '^(AVAILABLE|OPTIONAL/MANUAL) lean-ctx$'; then
  echo "doctor test FAIL: missing lean-ctx optional-tool line" >&2
  exit 1
fi

echo "Doctor lean-ctx test passed."
