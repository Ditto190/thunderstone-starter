#!/usr/bin/env bash
set -euo pipefail
if command -v node >/dev/null && node -e 'process.exit(Number(process.versions.node.split(".")[0])>=22?0:1)'; then exit 0; fi
if [[ -e /etc/alpine-release ]]; then
  echo "Alpine requires Node 22+ from a supported apk repository; no glibc binary will be installed." >&2; exit 1
fi
case "$(uname -m)" in x86_64) arch=x64;; aarch64|arm64) arch=arm64;; *) echo "Unsupported Node binary architecture"; exit 1;; esac
version=v22.23.2
dist="node-$version-linux-$arch"
mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
for bin in node npm npx; do
  [[ ! -e "$HOME/.local/bin/$bin" && ! -L "$HOME/.local/bin/$bin" ]] || { echo "Existing local $bin needs manual upgrade"; exit 1; }
done
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsS "https://nodejs.org/dist/$version/$dist.tar.xz" -o "$tmp/$dist.tar.xz"
curl --proto '=https' --tlsv1.2 -fsS "https://nodejs.org/dist/$version/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
(cd "$tmp"; awk -v f="$dist.tar.xz" '$2==f {print; found=1} END {if(!found)exit 1}' SHASUMS256.txt > selected.sha256; sha256sum -c selected.sha256)
[[ ! -e "$HOME/.local/opt/$dist" ]] || { echo "Existing Node install directory requires inspection"; exit 1; }
tar -xJf "$tmp/$dist.tar.xz" -C "$HOME/.local/opt"
for bin in node npm npx; do ln -s "$HOME/.local/opt/$dist/bin/$bin" "$HOME/.local/bin/$bin"; done
