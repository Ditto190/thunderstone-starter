#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if bash scripts/update-composio-skill.sh >/dev/null 2>&1; then
  echo "composio provenance FAIL: updater accepted a missing sha" >&2
  exit 1
fi
if bash scripts/update-composio-skill.sh not-a-sha >/dev/null 2>&1; then
  echo "composio provenance FAIL: updater accepted a bad sha" >&2
  exit 1
fi

python3 - <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(".")
record = json.loads((root / ".agents/skills/composio/PROVENANCE.json").read_text())
commit = record["commit"]
if len(commit) != 40 or any(c not in "0123456789abcdef" for c in commit):
    sys.exit("provenance commit is not 40 hex chars")
expected = {
    "SKILL.md",
    "references/errors.md",
    "references/for-you.md",
    "references/platform.md",
}
if set(record["files"]) != expected:
    sys.exit("provenance file set mismatch")
base = root / ".agents/skills/composio"
for rel, digest in record["files"].items():
    data = (base / rel).read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    if actual != digest:
        sys.exit(f"hash mismatch for {rel}")
print("composio provenance tests passed.")
PY
