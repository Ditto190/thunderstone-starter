#!/bin/sh
set -eu
cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
asroot() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then sudo -n "$@"
  else echo "Missing packages require root or passwordless sudo. Ask the VM administrator to run bootstrap." >&2; exit 1
  fi
}
missing=0
for tool in bash tmux git curl unzip zip jq rg fzf python3 node npm rclone shellcheck make cc tar xz flock; do
  command -v "$tool" >/dev/null 2>&1 || missing=1
done
if [ "$missing" -eq 1 ]; then
  if command -v apt-get >/dev/null 2>&1; then
    asroot apt-get update
    asroot env DEBIAN_FRONTEND=noninteractive apt-get install -y bash tmux git curl ca-certificates unzip zip jq ripgrep fzf python3 nodejs npm rclone shellcheck build-essential tar xz-utils util-linux
  elif command -v dnf >/dev/null 2>&1; then
    asroot dnf install -y bash tmux git curl ca-certificates unzip zip jq ripgrep fzf python3 nodejs npm rclone ShellCheck make gcc gcc-c++ tar xz util-linux
  elif command -v apk >/dev/null 2>&1; then
    asroot apk add bash tmux git curl ca-certificates unzip zip jq ripgrep fzf python3 nodejs npm rclone shellcheck build-base tar xz util-linux
  else echo "Unsupported package manager. Install required tools listed in README." >&2; exit 1; fi
fi
export PATH="$HOME/.local/bin:$PATH"
bash scripts/ensure-node.sh
node -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)'
if ! command -v agent >/dev/null 2>&1 && [ "${SKIP_CURSOR_INSTALL:-0}" != 1 ]; then
  mkdir -p .state
  curl --proto '=https' --tlsv1.2 -fsS https://cursor.com/install -o .state/cursor-install.sh
  bash .state/cursor-install.sh
fi
npm ci --no-audit --no-fund
bash scripts/doctor.sh
