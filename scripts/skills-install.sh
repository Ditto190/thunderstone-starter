#!/usr/bin/env bash
# Install pinned Agent Skills into .agents/skills, the directory Grok Build, Grok Bot and Cursor all read.
# Targets Grok / Grok Bot / Cursor only. Perplexity Computer skills are uploaded separately (see docs/agent-connectors/README.md).
#
# Usage: bash scripts/skills-install.sh [--check | --list | --update]
#   (no flag)  fetch each source at its pinned commit and copy the selected skills
#   --check    validate config/skills/manifest.json only; no network, nothing written
#   --list     print the skills each source would install
#   --update   move every source to its upstream HEAD, rewrite the manifest, then install
# Environment: SKILLS_SCOPE=user installs to ~/.agents/skills; SKILLS_SKIP=id,id skips sources by id.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
MANIFEST=config/skills/manifest.json
MODE="${1:-install}"
case "$MODE" in install|--check|--list|--update) ;; *) echo "Usage: $0 [--check|--list|--update]" >&2; exit 2;; esac
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

jq -e '.sources | type == "array" and length > 0 and all(.[];
  (.id | test("^[a-z0-9-]+$")) and (.repo | test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
  and (.ref | test("^[0-9a-f]{40}$")) and (.path | type == "string") and (.license | type == "string")
  and ((.include == "*") or (.include | type == "array")))' "$MANIFEST" >/dev/null \
  || { echo "Invalid $MANIFEST" >&2; exit 1; }
[ "$MODE" = "--check" ] && { echo "skills manifest ok ($(jq '.sources | length' "$MANIFEST") sources)"; exit 0; }

DEST=".agents/skills"
[ "${SKILLS_SCOPE:-project}" = "user" ] && DEST="$HOME/.agents/skills"
CACHE=".state/skills-src"
skip=",${SKILLS_SKIP:-},"

fetch_source() { # id repo ref
  local dir="$CACHE/$1"
  mkdir -p "$dir"
  [ -d "$dir/.git" ] || git init -q "$dir"
  if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" != "$3" ]; then
    git -C "$dir" fetch -q --depth 1 "https://github.com/$2.git" "$3"
    git -C "$dir" checkout -q --force FETCH_HEAD
  fi
}

skill_names() { # id -> skill directory names selected by the manifest
  local id="$1" path include
  path="$(jq -r --arg id "$id" '.sources[] | select(.id == $id) | .path' "$MANIFEST")"
  include="$(jq -r --arg id "$id" '.sources[] | select(.id == $id) | if .include == "*" then "*" else .include[] end' "$MANIFEST")"
  if [ "$include" = "*" ]; then
    local d
    for d in "$CACHE/$id/$path"/*/; do
      [ -f "${d}SKILL.md" ] && basename "$d"
    done
  else
    printf '%s\n' "$include"
  fi | grep -vxFf <(jq -r --arg id "$id" '.sources[] | select(.id == $id) | (.exclude // [])[]' "$MANIFEST") || true
}

if [ "$MODE" = "--update" ]; then
  tmp="$(mktemp)"
  cp "$MANIFEST" "$tmp"
  while IFS=' ' read -r id repo; do
    head="$(git ls-remote "https://github.com/$repo.git" HEAD | cut -f1)"
    [[ "$head" =~ ^[0-9a-f]{40}$ ]] || { echo "Could not resolve $repo" >&2; exit 1; }
    jq --arg id "$id" --arg ref "$head" '(.sources[] | select(.id == $id) | .ref) = $ref' "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
    echo "update $id -> ${head:0:7}"
  done < <(jq -r '.sources[] | "\(.id) \(.repo)"' "$MANIFEST")
  cp "$tmp" "$MANIFEST"; rm -f "$tmp"
fi

mkdir -p "$DEST"
install_vendored() {
  local vdir="config/skills/vendored"
  [ -d "$vdir" ] || return 0
  for d in "$vdir"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    local name target
    name="$(basename "$d")"
    target="$DEST/$name"
    if [ -e "$target" ] && [ ! -f "$target/.thunderstone-vendored" ] && [ ! -f "$target/.thunderstone-managed" ]; then
      echo "keep existing $target (not managed here)"
      continue
    fi
    rm -rf "$target"
    cp -R "$d" "$target"
    printf 'vendored\n' > "$target/.thunderstone-vendored"
  done
}
[ "$MODE" != "--list" ] && install_vendored
declare -A seen=()
installed=0
while IFS=' ' read -r id repo ref; do
  [[ "$skip" == *",$id,"* ]] && { echo "skip source $id"; continue; }
  fetch_source "$id" "$repo" "$ref"
  path="$(jq -r --arg id "$id" '.sources[] | select(.id == $id) | .path' "$MANIFEST")"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    src="$CACHE/$id/$path/$name"
    [ -f "$src/SKILL.md" ] || { echo "missing $id/$name" >&2; exit 1; }
    fm_name="$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/,""); gsub(/["\047]/,""); print; exit}' "$src/SKILL.md")"
    [ "$fm_name" = "$name" ] || { echo "$id/$name: frontmatter name '$fm_name' does not match directory" >&2; exit 1; }
    [ -z "${seen[$name]:-}" ] || { echo "Duplicate skill name '$name' in $id and ${seen[$name]}" >&2; exit 1; }
    seen[$name]="$id"
    if [ "$MODE" = "--list" ]; then echo "$id/$name"; continue; fi
    target="$DEST/$name"
    if [ -e "$target" ] && [ ! -f "$target/.thunderstone-managed" ]; then
      echo "keep existing $target (not managed here)"; continue
    fi
    rm -rf "$target"
    cp -R "$src" "$target"
    while IFS= read -r prune; do
      if [ -n "$prune" ]; then rm -rf "${target:?}/$prune"; fi
    done < <(jq -r --arg id "$id" '.sources[] | select(.id == $id) | (.prune // [])[]' "$MANIFEST")
    printf '%s %s %s\n' "$id" "$repo" "$ref" > "$target/.thunderstone-managed"
    installed=$((installed + 1))
  done < <(skill_names "$id")
done < <(jq -r '.sources[] | "\(.id) \(.repo) \(.ref)"' "$MANIFEST")
[ "$MODE" = "--list" ] || echo "Installed $installed skills into $DEST"
