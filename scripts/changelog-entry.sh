#!/usr/bin/env bash
# Render one Keep a Changelog bullet from merged-PR JSON (gh pr view --json number,title,labels,files,commits).
# usage: changelog-entry.sh --from-json <file|-> | changelog-entry.sh <pr-number>
set -euo pipefail
src="${1:-}"
case "$src" in
  --from-json) data="$(cat "${2:--}")" ;;
  ''|-*) echo "usage: $0 --from-json <file|-> | <pr-number>" >&2; exit 2 ;;
  *) data="$(gh pr view "$src" --json number,title,labels,files,commits)" ;;
esac
printf '%s' "$data" | node -e '
  let s = "";
  process.stdin.on("data", (d) => { s += d; });
  process.stdin.on("end", () => {
    const j = JSON.parse(s);
    const names = (j.labels || []).map((l) => l.name);
    let section = "Added";
    if (names.includes("breaking")) section = "Changed";
    else if (names.includes("security")) section = "Security";
    else if (names.includes("deps") || names.includes("docs")) section = "Changed";
    const files = j.files || [];
    const commits = j.commits || [];
    const labelBit = names.length ? " [" + names.join(", ") + "]" : "";
    const fileList = files.slice(0, 8).map((f) => f.path).join(", ") + (files.length > 8 ? ", ..." : "");
    const commitList = commits.slice(0, 6).map((c) => c.messageHeadline).join("; ") + (commits.length > 6 ? "; ..." : "");
    process.stdout.write(
      section + "\t- " + j.title + " (#" + j.number + ")" + labelBit + "\n"
      + "  - files (" + files.length + "): " + fileList + "\n"
      + "  - commits (" + commits.length + "): " + commitList + "\n"
    );
  });
'
