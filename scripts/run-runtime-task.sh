#!/usr/bin/env bash
# Lease a runtime task and print the compiled worker prompt. Does not launch Cursor CLI.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
task_id="${1:?Usage: run-runtime-task.sh <task-id> [worker]}"
worker="${2:-cursor-hammer}"
node scripts/agent-runtime.mjs lease --task-id "$task_id" --worker "$worker" >/dev/null
node scripts/agent-runtime.mjs prompt --task-id "$task_id"
