#!/usr/bin/env bash
# sessionStart: attach skill paths and surface a failed local CI run.
set -euo pipefail

if [ ! -t 0 ]; then
  cat >/dev/null || true
fi

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

skill_rel() {
  local name="$1"
  if [ -n "${THUNDERSTONE_SKILLS_ROOT:-}" ] \
    && [ -f "${THUNDERSTONE_SKILLS_ROOT}/${name}/SKILL.md" ]; then
    dollar='$'
    printf '%sTHUNDERSTONE_SKILLS_ROOT/%s/SKILL.md' "$dollar" "$name"
    return 0
  fi
  if [ -f ".cursor/skills/${name}/SKILL.md" ]; then
    printf '.cursor/skills/%s/SKILL.md' "$name"
    return 0
  fi
  if [ -n "${HOME:-}" ] && [ -f "${HOME}/.cursor/skills/${name}/SKILL.md" ]; then
    home_disp='~'
    printf '%s/.cursor/skills/%s/SKILL.md' "$home_disp" "$name"
    return 0
  fi
  return 1
}

found_parts=()
missing_parts=()
for name in caveman lean-ctx grok-agent-ops; do
  rel="$(skill_rel "$name" || true)"
  if [ -n "$rel" ]; then
    found_parts+=("${name} (${rel})")
  else
    missing_parts+=("$name")
  fi
done

ci_note=""
last_json=".state/session-ci/last.json"
if [ -f "$last_json" ] && command -v node >/dev/null 2>&1; then
  code="$(node -e '
    const fs = require("fs");
    try {
      const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      if (typeof j.exit === "number") process.stdout.write(String(j.exit));
    } catch (e) {}
  ' "$last_json" 2>/dev/null || true)"
  if [ -n "$code" ] && [ "$code" != "0" ]; then
    ci_note="last local CI: FAIL (exit ${code}, .state/session-ci/last.log)"
  fi
fi

msg=""
if [ "${#found_parts[@]}" -gt 0 ]; then
  msg="Skills:"
  for part in "${found_parts[@]}"; do
    msg+=" ${part}"
  done
  if [ "${#missing_parts[@]}" -gt 0 ]; then
    msg+="; missing:"
    for name in "${missing_parts[@]}"; do
      msg+=" ${name}"
    done
  fi
fi
if [ -n "$ci_note" ]; then
  if [ -n "$msg" ]; then
    msg+="; ${ci_note}"
  else
    msg="$ci_note"
  fi
fi

if [ -z "$msg" ]; then
  printf '{}\n'
  exit 0
fi

printf '{"additional_context":"%s"}\n' "$(json_escape "$msg")"
exit 0
