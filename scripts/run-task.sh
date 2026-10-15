#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
brief="${1:?Usage: run-task.sh <brief.md>}"
[[ -r "$brief" ]] || { echo "Brief not readable"; exit 1; }
# Ops tree is a sibling of this repo. pwd -P follows the thunderstone/scripts symlink.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ops_root="${THUNDERSTONE_OPERATIONAL_ROOT:-$(cd "$script_dir/../../thunderstone" && pwd)}"
L="$ops_root/state/cloud-agent-ledger.md"
D=$(TZ=Australia/Sydney date +%F)
if [[ -r "$L" ]] && grep -F "| $D |" "$L" | grep -qi 'usage-limit'; then echo "blocked: usage-limit recorded today (no retry)"; exit 75; fi
command -v agent >/dev/null || { echo "Install Cursor CLI first"; exit 1; }
exec agent -p --trust --force "Read AGENTS.md and the task brief at $brief. Execute only its scope. Do not spawn another Cursor CLI. Validate and save a concise report under workspace/reports. Do not push, deploy or send messages."
