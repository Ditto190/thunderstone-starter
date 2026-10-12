#!/usr/bin/env bash
# Refresh the vendored Composio skill from an explicit commit SHA.
# Not part of npm test. Requires network. Does not print file contents.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

sha="${1:-}"
if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "usage: scripts/update-composio-skill.sh <40-hex-sha>" >&2
  exit 2
fi

base="https://raw.githubusercontent.com/ComposioHQ/composio/${sha}/skills/composio"
dest=".agents/skills/composio"
mkdir -p "${dest}/references"
curl -fsSL "${base}/SKILL.md" -o "${dest}/SKILL.md"
curl -fsSL "${base}/references/errors.md" -o "${dest}/references/errors.md"
curl -fsSL "${base}/references/for-you.md" -o "${dest}/references/for-you.md"
curl -fsSL "${base}/references/platform.md" -o "${dest}/references/platform.md"

python3 - "$sha" "$dest" <<'PY'
import hashlib, json, pathlib, sys
sha, dest = sys.argv[1], pathlib.Path(sys.argv[2])
files = [
    "SKILL.md",
    "references/errors.md",
    "references/for-you.md",
    "references/platform.md",
]
doc = {
    "repository": "https://github.com/ComposioHQ/composio",
    "commit": sha,
    "path": "skills/composio",
    "files": {rel: hashlib.sha256((dest / rel).read_bytes()).hexdigest() for rel in files},
}
(dest / "PROVENANCE.json").write_text(json.dumps(doc, indent=2) + "\n")
PY

echo "composio skill updated to ${sha}"
