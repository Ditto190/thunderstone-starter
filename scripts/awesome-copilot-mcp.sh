#!/usr/bin/env bash
# Start the official Awesome Copilot catalogue MCP on loopback.
# Docker is not installed by scripts/bootstrap.sh. There is no shared public host.
set -euo pipefail

image="ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot:latest"
port="${AWESOME_COPILOT_PORT:-8080}"
name="thunderstone-awesome-copilot"

if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' \
    "Docker is not installed. Thunderstone bootstrap does not install it." \
    "Official catalogue image: ${image}" \
    "No shared public HTTPS host exists. Do not copy agent trees into this repo." >&2
  exit 2
fi

if docker ps --filter "name=^/${name}$" --format '{{.Names}}' | grep -qx "${name}"; then
  printf 'awesome-copilot MCP already running. Client URL: http://127.0.0.1:%s/mcp\n' "${port}"
  exit 0
fi

docker run -d --rm --name "${name}" -p "127.0.0.1:${port}:8080" "${image}" --http
printf 'Started. Client URL (this machine only): http://127.0.0.1:%s/mcp\n' "${port}"
printf '%s\n' "Do not register that loopback URL on grok.com."
