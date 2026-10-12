#!/bin/sh
# Idempotent LeanCTX install. Never guesses a marketplace command.
set -eu
export PATH="${HOME}/.local/bin:${PATH}"
if command -v lean-ctx >/dev/null 2>&1; then
  echo "OK lean-ctx"
  exit 0
fi
url="${LEAN_CTX_RELEASE_URL:-}"
if [ -z "$url" ]; then
  echo "OPTIONAL/MANUAL lean-ctx: LEAN_CTX_RELEASE_URL unset; no install guessed." >&2
  exit 0
fi
case "$url" in
  https://*) ;;
  *)
    echo "LEAN_CTX_RELEASE_URL must use https." >&2
    exit 1
    ;;
esac
mkdir -p "${HOME}/.local/bin"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$tmp"
if [ -n "${LEAN_CTX_SHA256:-}" ]; then
  actual="$(sha256sum "$tmp" | awk '{print $1}')"
  if [ "$actual" != "$LEAN_CTX_SHA256" ]; then
    echo "lean-ctx checksum mismatch" >&2
    exit 1
  fi
fi
chmod 755 "$tmp"
mv "$tmp" "${HOME}/.local/bin/lean-ctx"
trap - EXIT
echo "OK lean-ctx installed"
