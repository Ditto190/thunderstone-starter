#!/usr/bin/env bash
# afterFileEdit: index paths under reports/. Stdout stays {}.
set -euo pipefail

state_dir="${HOOKS_STATE_DIR:-.cursor/hooks/state}"
stdin="$(cat || true)"

rel="$(
  printf '%s' "$stdin" | node -e '
    let s = "";
    process.stdin.on("data", (d) => { s += d; });
    process.stdin.on("end", () => {
      let file = "";
      try {
        const j = JSON.parse(s);
        if (j && typeof j.file_path === "string") file = j.file_path;
        else if (j && typeof j.path === "string") file = j.path;
      } catch (e) {}
      const norm = file.replace(/\\/g, "/").replace(/^\.\//, "");
      const wr = "workspace/reports/";
      const rp = "reports/";
      let rel = "";
      const i = norm.indexOf(wr);
      if (i >= 0) rel = norm.slice(i);
      else if (norm === "reports" || norm.startsWith(rp)) rel = norm;
      else {
        const j = norm.lastIndexOf("/" + rp);
        if (j >= 0) rel = norm.slice(j + 1);
      }
      if (rel.startsWith(rp) || rel.startsWith(wr)) process.stdout.write(rel);
    });
  '
)"

if [ -z "$rel" ]; then
  printf '{}\n'
  exit 0
fi

mkdir -p "$state_dir"
index="${state_dir}/reports-index.md"
if [ -f "$index" ] && grep -qxF -- "- ${rel}" "$index"; then
  printf '{}\n'
  exit 0
fi
printf -- '- %s\n' "$rel" >>"$index"
printf '{}\n'
exit 0
