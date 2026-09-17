#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
brief="${1:?Usage: run-task.sh <brief.md>}"
[[ -r "$brief" ]] || { echo "Brief not readable"; exit 1; }
command -v agent >/dev/null || { echo "Install Cursor CLI first"; exit 1; }
exec agent -p "Read AGENTS.md and the task brief at $brief. Execute only its scope. Do not spawn another Cursor CLI. Validate and save a concise report under workspace/reports. Do not push, deploy or send messages."
