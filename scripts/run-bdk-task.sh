#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
brief="${1:?Usage: run-bdk-task.sh <brief.md> [domainId]}"
domain="${2:-pr_orchestration}"
[[ -r "$brief" ]] || { echo "Brief not readable: $brief"; exit 1; }
AGENT_DIR="$ROOT/agents/clan-orchestrator"
[[ -d "$AGENT_DIR/bot" ]] || { echo "Missing $AGENT_DIR"; exit 1; }
exec npx @cursor/bdk@latest run --dir "$AGENT_DIR" --message "Read the task brief at $brief. Domain id: $domain. Follow bot/instructions.md and clan-orchestrator skills. Save a concise report under workspace/reports. Do not push or post reviews."
