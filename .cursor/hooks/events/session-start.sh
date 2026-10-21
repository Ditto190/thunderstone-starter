#!/usr/bin/env bash
# sessionStart: stage router + skill note + optional bridge drift. Once per session.
set -euo pipefail

hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_dir="${HOOKS_STATE_DIR:-.cursor/hooks/state}"
stdin="$(cat || true)"

session_key="$(
  printf '%s' "$stdin" | node -e '
    const crypto = require("crypto");
    let s = "";
    process.stdin.on("data", (d) => { s += d; });
    process.stdin.on("end", () => {
      let id = "";
      try {
        const j = JSON.parse(s);
        if (j && typeof j.conversation_id === "string" && j.conversation_id) id = j.conversation_id;
        else if (j && typeof j.session_id === "string" && j.session_id) id = j.session_id;
      } catch (e) {}
      if (!id) id = crypto.createHash("sha256").update(s).digest("hex");
      process.stdout.write(id.replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 120));
    });
  '
)"

mkdir -p "${state_dir}/seen"
marker="${state_dir}/seen/sessionStart-${session_key}"
if [ -f "$marker" ]; then
  printf '{}\n'
  exit 0
fi
: >"$marker"

context_of() {
  local script="$1"
  local raw ctx
  raw="$(printf '%s' "$stdin" | bash "$script" 2>/dev/null || true)"
  ctx="$(
    printf '%s' "$raw" | node -e '
      let s = "";
      process.stdin.on("data", (d) => { s += d; });
      process.stdin.on("end", () => {
        try {
          const j = JSON.parse(s);
          if (j && typeof j.additional_context === "string") process.stdout.write(j.additional_context);
        } catch (e) {}
      });
    ' 2>/dev/null || true
  )"
  printf '%s' "$ctx"
}

parts=()
stage="$(context_of "${hooks_dir}/stage-router.sh")"
skills="$(context_of "${hooks_dir}/session-skills.sh")"
[ -n "$stage" ] && parts+=("$stage")
[ -n "$skills" ] && parts+=("$skills")

drift_note=""
if [ -n "${THUNDERSTONE_ROOT:-}" ] && [ -d "${THUNDERSTONE_ROOT}/bridge" ] && [ -d "workspace/bridge" ]; then
  left="${THUNDERSTONE_ROOT}/bridge"
  right="workspace/bridge"
  drift_n="$(
    LEFT="$left" RIGHT="$right" node -e '
      const fs = require("fs");
      const path = require("path");
      const left = process.env.LEFT;
      const right = process.env.RIGHT;
      function rels(base) {
        const out = new Set();
        function walk(dir, prefix) {
          if (!fs.existsSync(dir)) return;
          for (const name of fs.readdirSync(dir)) {
            const abs = path.join(dir, name);
            const rel = prefix ? prefix + "/" + name : name;
            const st = fs.statSync(abs);
            if (st.isDirectory()) walk(abs, rel);
            else if (st.isFile()) out.add(rel);
          }
        }
        walk(path.join(base, "src"), "src");
        walk(path.join(base, "scripts"), "scripts");
        if (fs.existsSync(base)) {
          for (const name of fs.readdirSync(base)) {
            if (/^package.*\.json$/.test(name)) {
              const abs = path.join(base, name);
              if (fs.statSync(abs).isFile()) out.add(name);
            }
          }
        }
        return out;
      }
      const a = rels(left);
      const b = rels(right);
      const names = new Set([...a, ...b]);
      let n = 0;
      for (const rel of names) {
        const pa = path.join(left, rel);
        const pb = path.join(right, rel);
        const ha = fs.existsSync(pa) ? fs.readFileSync(pa) : null;
        const hb = fs.existsSync(pb) ? fs.readFileSync(pb) : null;
        if (ha === null || hb === null || !ha.equals(hb)) n += 1;
      }
      process.stdout.write(String(n));
    '
  )"
  if [ -n "$drift_n" ] && [ "$drift_n" != "0" ]; then
    drift_note="DRIFT bridge: ${drift_n} files"
    parts+=("$drift_note")
  fi
fi

if [ "${#parts[@]}" -eq 0 ]; then
  printf '{}\n'
  exit 0
fi

msg=""
for part in "${parts[@]}"; do
  if [ -n "$msg" ]; then
    msg+="; ${part}"
  else
    msg="$part"
  fi
done

printf '%s' "$msg" | node -e '
  let s = "";
  process.stdin.on("data", (d) => { s += d; });
  process.stdin.on("end", () => {
    process.stdout.write(JSON.stringify({ additional_context: s }));
    process.stdout.write("\n");
  });
'
exit 0
