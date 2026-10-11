# shellcheck shell=bash
# Sourced by scripts/check-hygiene.sh and .cursor/hooks/stage-router.sh.
# This file is the only copy of the secret and absolute-path rules.
# It does not enable shell options. Callers own set -e.

hygiene_email_allow='(@(users\.noreply\.github\.com|noreply\.github\.com|example\.(com|org|net))|^noreply@github\.com)$'

hygiene_names=(
  absolute-home-path
  absolute-workspace-path
  windows-drive-path
  local-project-dir
  email-address
  private-key
  github-token
  generic-api-key
  aws-access-key
  google-api-key
  slack-token
  credential-assignment
)

hygiene_patterns=(
  '(^|[^A-Za-z0-9_.-])/(home|Users|root)/[A-Za-z0-9_.-]+'
  $'(^|[[:space:]=,:`([])(["'"'"'])?/workspace(/|[[:space:]"'"'"'`]|$)'
  '(^|[^A-Za-z])[A-Za-z]:\\[A-Za-z0-9_.-]'
  'Github_Projects'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'
  '(sk|xai|crsr|key)[-_][A-Za-z0-9_-]{20,}'
  'AKIA[0-9A-Z]{16}'
  'AIza[0-9A-Za-z_-]{35}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  '(api[_-]?key|secret|token|passw(or)?d)[A-Za-z_]*[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+_-]{20,}'
)

hygiene_report_hits() {
  local name="$1"
  local lineno match
  while IFS=: read -r lineno match; do
    [ -n "${lineno:-}" ] || continue
    if [ "$name" = "email-address" ] && printf '%s' "$match" | grep -Eq "$hygiene_email_allow"; then
      continue
    fi
    printf '%s %s\n' "$lineno" "$name"
  done
}

hygiene_scan_text() {
  local text="$1"
  local i name pattern
  for i in "${!hygiene_names[@]}"; do
    name="${hygiene_names[$i]}"
    pattern="${hygiene_patterns[$i]}"
    hygiene_report_hits "$name" < <(printf '%s\n' "$text" | grep -nEoi -e "$pattern" || true)
  done
  return 0
}

hygiene_scan_file() {
  local file="$1"
  local i name pattern
  for i in "${!hygiene_names[@]}"; do
    name="${hygiene_names[$i]}"
    pattern="${hygiene_patterns[$i]}"
    hygiene_report_hits "$name" < <(grep -nEoi -e "$pattern" -- "$file" || true)
  done
  return 0
}
