#!/usr/bin/env bash
# Read-only check: canonical skills vs mirrors, and catalog pickup.
# On demand only. Never writes outside mktemp. Never runs fix commands.
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CATALOG_JS="$SCRIPT_DIR/catalog.mjs"

canonical=""
mirrors=()
catalog_dir=""
json=0
quiet=0
print_fix=0
strict=0

usage() {
  echo "usage: skills-sync-check.sh [--canonical DIR] [--mirror DIR]... [--catalog DIR] [--json] [--quiet] [--print-fix] [--strict]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --canonical)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      canonical=$2
      shift 2
      ;;
    --mirror)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      mirrors+=("$2")
      shift 2
      ;;
    --catalog)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      catalog_dir=$2
      shift 2
      ;;
    --json) json=1; shift ;;
    --quiet) quiet=1; shift ;;
    --print-fix) print_fix=1; shift ;;
    --strict) strict=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [ -z "$canonical" ]; then
  if [ -n "${THUNDERSTONE_SKILLS_ROOT:-}" ]; then
    canonical=$THUNDERSTONE_SKILLS_ROOT
  else
    canonical="$SCRIPT_DIR/../skills"
  fi
fi

if [ "${#mirrors[@]}" -eq 0 ] && [ -n "${SKILLS_MIRRORS:-}" ]; then
  IFS=':' read -r -a mirrors <<< "$SKILLS_MIRRORS"
fi

if [ ! -d "$canonical" ]; then
  echo "skills-sync: canonical root not found" >&2
  exit 2
fi
canonical=$(CDPATH='' cd -- "$canonical" && pwd)

if [ -n "$catalog_dir" ] && [ ! -f "$catalog_dir/catalog.json" ]; then
  echo "skills-sync: catalog.json missing" >&2
  exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

node --input-type=module - "$canonical" >"$work/skills.tsv" <<'JS'
import { readdirSync, readFileSync, lstatSync } from 'node:fs';
import { join, basename, sep } from 'node:path';

const root = process.argv[2];
const rows = [];

function parseFm(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const o = {};
  let key = null;
  for (const line of m[1].split(/\r?\n/)) {
    if (/^\s*$/.test(line) || /^\s*#/.test(line)) continue;
    const kv = line.match(/^([A-Za-z_][A-Za-z0-9_-]*):(?:\s+(.*)|\s*)$/);
    if (kv) {
      key = kv[1];
      if (Object.hasOwn(o, key)) return { error: 'duplicate' };
      let v = (kv[2] || '').trim();
      if (/^[>|][-+]?$/.test(v)) v = '';
      o[key] = v.replace(/^'(.*)'$/, '$1').replace(/^"(.*)"$/, '$1');
    } else if (key && /^\s+\S/.test(line)) {
      o[key] = `${o[key]} ${line.trim()}`.trim();
    } else {
      return { error: 'unparseable' };
    }
  }
  return o;
}

function walk(dir, depth) {
  if (depth > 4) return;
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name.startsWith('.')) continue;
    const p = join(dir, e.name);
    let st;
    try { st = lstatSync(p); } catch { continue; }
    if (st.isSymbolicLink()) continue;
    if (st.isDirectory()) walk(p, depth + 1);
    else if (st.isFile() && e.name === 'SKILL.md' && dir !== root) {
      const id = basename(dir);
      const rel = dir.slice(root.length + 1).split(sep).join('/');
      let fm;
      try { fm = parseFm(readFileSync(p, 'utf8')); } catch { fm = null; }
      let scope = 'invalid';
      let nameOk = '0';
      let reason = 'unreadable';
      if (fm && fm.error) {
        reason = fm.error;
      } else if (!fm) {
        reason = 'no-frontmatter';
      } else {
        const raw = Object.hasOwn(fm, 'scope') ? String(fm.scope).trim().toLowerCase() : 'shared';
        const desc = String(fm.description || '').replace(/\s+/g, ' ').trim();
        nameOk = fm.name === id ? '1' : '0';
        if (raw === 'private') {
          scope = 'private';
          reason = desc ? 'private' : 'private-no-description';
        } else if (raw !== 'shared') {
          reason = 'unknown-scope';
        } else if (!desc) {
          reason = 'no-description';
        } else {
          scope = 'shared';
          reason = nameOk === '1' ? 'ok' : 'name-mismatch';
        }
      }
      rows.push([id, rel, scope, nameOk, reason].join('\t'));
    }
  }
}
walk(root, 0);
rows.sort();
process.stdout.write(rows.length ? `${rows.join('\n')}\n` : '');
JS

node "$CATALOG_JS" gen --root "$canonical" --out "$work/fresh" >/dev/null 2>&1

node --input-type=module - "$work/fresh/catalog.json" >"$work/fresh.ids" <<'JS'
import { readFileSync } from 'node:fs';
const cat = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const ids = (cat.items || []).map((i) => i.id).sort();
process.stdout.write(ids.length ? `${ids.join('\n')}\n` : '');
JS

fail=0
rows_file="$work/rows.tsv"
: >"$rows_file"
fixes="$work/fixes.txt"
: >"$fixes"

add_row() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >>"$rows_file"
}

while IFS=$'\t' read -r id rel scope name_ok reason; do
  [ -n "${id:-}" ] || continue
  if [ "$scope" = "shared" ] && [ "$name_ok" != "1" ]; then
    add_row warn "$id" - "name-mismatch"
  elif [ "$scope" = "invalid" ]; then
    add_row warn "$id" - "$reason"
  fi
  if [ "$scope" = "shared" ]; then
    if ! grep -Fxq -- "$id" "$work/fresh.ids"; then
      add_row pickup "$id" catalog "missing-from-fresh"
      fail=1
    fi
  elif [ "$scope" = "private" ]; then
    if grep -Fxq -- "$id" "$work/fresh.ids"; then
      add_row pickup "$id" catalog "private-in-fresh"
      fail=1
    fi
  fi
done <"$work/skills.tsv"

if [ -n "$catalog_dir" ]; then
  node --input-type=module - "$catalog_dir/catalog.json" >"$work/given.ids" <<'JS'
import { readFileSync } from 'node:fs';
const cat = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const ids = (cat.items || []).map((i) => i.id).sort();
process.stdout.write(ids.length ? `${ids.join('\n')}\n` : '');
JS
  if ! cmp -s "$work/fresh.ids" "$work/given.ids"; then
    add_row pickup - catalog "ids-differ"
    fail=1
  fi
  llms="$catalog_dir/llms.txt"
  if [ ! -f "$llms" ]; then
    add_row pickup - catalog "llms-missing"
    fail=1
  else
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      if ! grep -Fq -- "[$id]" "$llms"; then
        add_row pickup "$id" catalog "missing-from-llms"
        fail=1
      fi
    done <"$work/fresh.ids"
  fi
  stale=0
  while IFS= read -r skillmd; do
    if [ "$skillmd" -nt "$catalog_dir/catalog.json" ]; then
      stale=1
      break
    fi
  done < <(find "$canonical" -name SKILL.md -type f -print)
  if [ "$stale" -eq 1 ]; then
    add_row stale - catalog "skill-newer-than-catalog"
    fail=1
  fi
fi

finger() {
  node --input-type=module - "$1" <<'JS'
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, lstatSync } from 'node:fs';
import { join } from 'node:path';
const root = process.argv[2];
const lines = [];
function walk(dir, base) {
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
  entries.sort((a, b) => a.name.localeCompare(b.name));
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name.startsWith('.')) continue;
    const p = join(dir, e.name);
    const rel = base ? `${base}/${e.name}` : e.name;
    let st;
    try { st = lstatSync(p); } catch { continue; }
    if (st.isSymbolicLink()) lines.push(`${rel}\tsymlink`);
    else if (st.isDirectory()) walk(p, rel);
    else if (st.isFile()) {
      const h = createHash('sha256').update(readFileSync(p)).digest('hex');
      lines.push(`${rel}\t${h}`);
    }
  }
}
walk(root, '');
lines.sort();
process.stdout.write(lines.length ? `${lines.join('\n')}\n` : '');
JS
}

mirror_index() {
  node --input-type=module - "$1" <<'JS'
import { readdirSync, lstatSync } from 'node:fs';
import { join, basename } from 'node:path';
const root = process.argv[2];
const rows = [];
function walk(dir, depth) {
  if (depth > 4) return;
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name.startsWith('.')) continue;
    const p = join(dir, e.name);
    let st;
    try { st = lstatSync(p); } catch { continue; }
    if (st.isSymbolicLink()) continue;
    if (st.isDirectory()) walk(p, depth + 1);
    else if (st.isFile() && e.name === 'SKILL.md' && dir !== root) {
      rows.push(`${basename(dir)}\t${dir.slice(root.length + 1)}`);
    }
  }
}
walk(root, 0);
process.stdout.write(rows.length ? `${rows.join('\n')}\n` : '');
JS
}

if [ "${#mirrors[@]}" -gt 0 ]; then
  for mirror in "${mirrors[@]}"; do
    [ -n "$mirror" ] || continue
    if [ ! -d "$mirror" ]; then
      add_row missing - "$mirror" "mirror-root-missing"
      fail=1
      continue
    fi
    mirror=$(CDPATH='' cd -- "$mirror" && pwd)
    : >"$work/seen.ids"
    while IFS=$'\t' read -r id rel _scope _name _reason; do
      [ -n "${id:-}" ] || continue
      printf '%s\n' "$id" >>"$work/seen.ids"
      dest="$mirror/$rel"
      src="$canonical/$rel"
      if [ -L "$dest" ]; then
        target=$(readlink -f -- "$dest" || true)
        src_real=$(readlink -f -- "$src" || true)
        if [ -n "$target" ] && [ "$target" = "$src_real" ]; then
          add_row ok "$id" "$mirror" "symlink"
        else
          add_row drift "$id" "$mirror" "bad-symlink"
          fail=1
          printf 'rsync -a --delete -- %q/ %q/\n' "$src" "$dest" >>"$fixes"
        fi
        continue
      fi
      if [ ! -d "$dest" ]; then
        add_row missing "$id" "$mirror" "absent"
        fail=1
        printf 'rsync -a --delete -- %q/ %q/\n' "$src" "$dest" >>"$fixes"
        continue
      fi
      finger "$src" >"$work/src.fp"
      finger "$dest" >"$work/dst.fp"
      if cmp -s "$work/src.fp" "$work/dst.fp"; then
        add_row ok "$id" "$mirror" "match"
      else
        diff_files=$(sort "$work/src.fp" "$work/dst.fp" | uniq -u | cut -f1 | sort -u | paste -sd, -)
        add_row drift "$id" "$mirror" "${diff_files:-files}"
        fail=1
        printf 'rsync -a --delete -- %q/ %q/\n' "$src" "$dest" >>"$fixes"
      fi
    done <"$work/skills.tsv"

    mirror_index "$mirror" >"$work/mirror.idx"
    if [ -s "$work/mirror.idx" ]; then
      while IFS=$'\t' read -r mid mrel; do
        [ -n "${mid:-}" ] || continue
        if ! grep -Fxq -- "$mid" "$work/seen.ids"; then
          add_row extra "$mid" "$mirror" "$mrel"
          if [ "$strict" -eq 1 ]; then
            fail=1
          fi
        fi
      done <"$work/mirror.idx"
    fi
  done
fi

if [ "$fail" -eq 0 ] && [ "$quiet" -eq 1 ]; then
  :
else
  if [ "$json" -eq 1 ]; then
    node --input-type=module - "$rows_file" <<'JS'
import { readFileSync } from 'node:fs';
const text = readFileSync(process.argv[2], 'utf8').trim();
const rows = text ? text.split('\n').map((line) => {
  const [status, id, mirror, detail] = line.split('\t');
  return { status, id, mirror, detail };
}) : [];
process.stdout.write(`${JSON.stringify(rows)}\n`);
JS
  elif [ -s "$rows_file" ]; then
    cat "$rows_file"
  fi
fi

if [ "$print_fix" -eq 1 ] && [ -s "$fixes" ]; then
  cat "$fixes"
fi

exit "$fail"
