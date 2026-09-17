#!/usr/bin/env bash
set -euo pipefail
: "${DRIVE_EXPORT_ROOT:?Set the active project Drive export path}"
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$root/workspace/exports"
[[ -d "$source_dir" ]] || { echo "Create curated workspace/exports first."; exit 1; }
if find "$source_dir" -type l -print -quit | read -r _; then echo "Symlinks not permitted in exports"; exit 1; fi
run="$(date -u +%Y%m%dT%H%M%SZ)-$(node -e 'console.log(require("crypto").randomUUID())')"
rclone copy "$source_dir" "${GDRIVE_REMOTE:-gdrive}:${DRIVE_EXPORT_ROOT%/}/$run" --immutable \
  --exclude '.env*' --exclude '*.pem' --exclude '*.key' --exclude '.git/**' --exclude 'node_modules/**' --exclude '*.log'
echo "Curated exports uploaded to run $run"
