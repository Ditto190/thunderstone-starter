#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname -- "${BASH_SOURCE[0]}")/resume.sh"
exec tmux attach-session -t thunderstone
