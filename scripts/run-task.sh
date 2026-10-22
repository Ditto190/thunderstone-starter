#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
brief="${1:?Usage: run-task.sh <brief.md>}"
[[ -r "$brief" ]] || { echo "Brief not readable"; exit 1; }
# Ops tree is a sibling of this repo. pwd -P follows the thunderstone/scripts symlink.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ops_root=""
if [[ -n "${THUNDERSTONE_OPERATIONAL_ROOT:-}" ]]; then
  ops_root="$THUNDERSTONE_OPERATIONAL_ROOT"
elif [[ -d "$script_dir/../../thunderstone" ]]; then
  ops_root="$(cd "$script_dir/../../thunderstone" && pwd)"
else
  echo "warn: ops root unresolved; skipping usage-limit guard" >&2
fi
if [[ -n "$ops_root" ]]; then
  L="$ops_root/state/cloud-agent-ledger.md"
  D=$(TZ=Australia/Sydney date +%F)
  # Block only when today's row has a status field (last column) starting with
  # "usage-limit"; free-text mentions elsewhere in a row must not block.
  if [[ -r "$L" ]] && awk -F'|' -v d="$D" '
    { n=NF; if ($n ~ /^[[:space:]]*$/) n--; date=$2; st=$n
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", date); gsub(/^[[:space:]]+/, "", st)
      if (date == d && tolower(st) ~ /^usage-limit/) { found=1; exit } }
    END { exit !found }' "$L"; then echo "blocked: usage-limit recorded today (no retry)"; exit 75; fi
fi
command -v agent >/dev/null || { echo "Install Cursor CLI first"; exit 1; }
# DT standing law: VM agents have full auto-permission; keep --trust --force.
exec agent -p --trust --force "Read AGENTS.md and the task brief at $brief. Execute only its scope. Do not spawn another Cursor CLI. Validate and save a concise report under workspace/reports. Do not push, deploy or send messages."
