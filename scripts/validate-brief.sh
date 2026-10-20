#!/usr/bin/env bash
# Minimal brief validation for investigator handoff gate.
set -euo pipefail
BRIEF="${1:?brief path}"
[[ -f "$BRIEF" ]] || { echo "brief missing: $BRIEF" >&2; exit 1; }
grep -qE '^# ' "$BRIEF" || { echo "brief needs H1 title" >&2; exit 1; }
awk '
  /^(```|~~~)/ { fenced = !fenced; next }
  !fenced && /^## (Goal|Objective)([[:space:]]|$)/ { goal = 1 }
  !fenced && /^## Acceptance([[:space:]]|$)/ { accept = 1 }
  END { exit !(goal && accept) }
' "$BRIEF" || { echo "brief needs ## Goal or ## Objective and ## Acceptance" >&2; exit 1; }
echo "brief_valid"
