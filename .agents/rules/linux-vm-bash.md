---
description: Linux VM, WSL, and Grok Remote Computer execution guidelines
globs: ["**/*.sh", "scripts/**/*", "workspace/scripts/**/*"]
always_on: false
---

# Linux VM & Bash Execution Guidelines

When working inside the Grok Remote Computer, WSL2 Ubuntu, or Linux CI environments:

## 1. Strict Script Hygiene
- Every Bash script must begin with:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```
- All scripts must pass ShellCheck validation (`npm run lint`).
- Always quote variable expansions: `"$variable"`, `"${array[@]}"`.

## 2. Process & Session Management
- **Persistence:** Work runs inside named tmux sessions (`tmux attach -t thunderstone`).
- **File Locking:** Use kernel `flock` (e.g. `scripts/resume.sh`) to prevent concurrent competing agent instances on the same checkout.
- **Port & Process Inspection:** Use `lsof -i :<port>` and `ps aux | grep <name>` for deterministic debugging before terminating processes.

## 3. Safe Handoffs & File I/O
- Always use atomic write patterns (`mktemp` + `mv` or hardlink `ln`) when saving receipts or brief files.
- Keep bot-to-bot handoff payloads under 300 characters in chat/signal channels, storing larger bodies in versioned files under `workspace/handoffs/`.
