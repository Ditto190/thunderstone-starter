#!/usr/bin/env bash
# Replace the vendored Composio skill with one explicit upstream commit.
# Usage: bash scripts/update-composio-skill.sh <40-hex-sha>
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

sha="${1:-}"
if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "usage: bash scripts/update-composio-skill.sh <40-hex-sha>" >&2
  exit 2
fi

base="https://raw.githubusercontent.com/ComposioHQ/composio/${sha}/skills/composio"
dest=".agents/skills/composio"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/references"
curl --fail --silent --show-error --connect-timeout 10 --max-time 60 -o "$tmp/SKILL.md" "${base}/SKILL.md"
curl --fail --silent --show-error --connect-timeout 10 --max-time 60 -o "$tmp/references/errors.md" "${base}/references/errors.md"
curl --fail --silent --show-error --connect-timeout 10 --max-time 60 -o "$tmp/references/for-you.md" "${base}/references/for-you.md"
curl --fail --silent --show-error --connect-timeout 10 --max-time 60 -o "$tmp/references/platform.md" "${base}/references/platform.md"

python3 - "$sha" "$tmp" "$dest" <<'PY'
import hashlib, json, pathlib, shutil, sys
sha, src, dest = sys.argv[1:]
src_path, dest_path = pathlib.Path(src), pathlib.Path(dest)
rel_files = [
    "SKILL.md",
    "references/errors.md",
    "references/for-you.md",
    "references/platform.md",
]
files = {}
for rel in rel_files:
    data = (src_path / rel).read_bytes()
    files[rel] = hashlib.sha256(data).hexdigest()
    target = dest_path / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
record = {
    "repository": "https://github.com/ComposioHQ/composio",
    "commit": sha,
    "upstreamPath": "skills/composio",
    "files": files,
}
(dest_path / "PROVENANCE.json").write_text(json.dumps(record, indent=2) + "\n")
PY

echo "Updated Composio skill to ${sha}"
