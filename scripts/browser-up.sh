#!/usr/bin/env bash
# Start CloakBrowser CDP sidecar on loopback only.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
PORT="${BROWSER_CDP_PORT:-9222}"
NAME="${BROWSER_CONTAINER:-cloakbrowser}"
IMAGE="${CLOAK_IMAGE:-cloakhq/cloakbrowser}"
mkdir -p .state/browser/profiles
command -v docker >/dev/null || { echo "docker required" >&2; exit 1; }
if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then echo "$NAME already running"; exit 0; fi
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --restart unless-stopped \
  -p "127.0.0.1:${PORT}:9222" \
  -v "$PWD/.state/browser/profiles:/profiles" \
  "$IMAGE" cloakserve --headless=false --idle-timeout="${BROWSER_IDLE_TIMEOUT:-600}"
for _ in $(seq 1 30); do
  curl -fsS "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1 && { echo "CDP ready on 127.0.0.1:${PORT}"; exit 0; }
  sleep 1
done
echo "CDP not ready; check: docker logs $NAME" >&2; exit 1
