#!/usr/bin/env node
// catalog.mjs - zero-dependency skill catalog and selector (Node >= 22).
//
//   catalog.mjs gen [--root DIR] [--out DIR] [--verbose]
//       Index SKILL.md files under ONE canonical root. Prints catalog.json on
//       stdout, or writes catalog.json + llms.txt into --out DIR.
//   catalog.mjs select CATALOG "task" [--kind skill] [--top N] [--json]
//                      [--root DIR]
//
// Canonical root: --root, else $THUNDERSTONE_SKILLS_ROOT, else ../skills next to
// this script (the deployed skills folder). A missing root is an error, never a
// guess. Nothing outside the root is ever read.
//
// PRIVATE DENY-BY-DEFAULT (fail closed, never guess):
//   * items with frontmatter `scope: private` are never written to any output
//     and never returned by select, even on an exact id match;
//   * symlinks (files or directories) are never followed, so nothing that
//     resolves outside the root is indexed;
//   * unparseable frontmatter, an unknown `scope` value, duplicate keys or a
//     missing description make the item skipped;
//   * select re-verifies every candidate against the file on disk, so a stale
//     or hand-edited catalog cannot surface a private or out-of-root item.
import {lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, writeFileSync} from 'node:fs';
import {basename, dirname, join, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';

// Deployed layout: <home>/scripts/catalog.mjs next to <home>/skills. No machine path is baked in.
const DEFAULT_ROOT = fileURLToPath(new URL('../skills', import.meta.url));
const MAX_BYTES = 1024 * 1024;
const MAX_DEPTH = 4;
const COST = {skill: 'S'};
const KINDS = Object.keys(COST);
const STOP = new Set('a an the and or of to for in on with when use used this that is are be it as at by from any one your you not do'.split(' '));
const SECRETISH = /(api[_-]?key|token|secret|password)\s*[=:]\s*\S{8,}/i;
const toks = s => [...new Set((s.toLowerCase().match(/[a-z0-9][a-z0-9-]{1,}/g) || []).filter(w => !STOP.has(w)))];

function fail(msg, code = 2) { console.error(`catalog: ${msg}`); process.exit(code); }

// Strict frontmatter parser. Throws on anything it cannot parse.
function parseFrontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/);
  if (!m) throw new Error('no frontmatter');
  const o = {};
  let key = null;
  for (const line of m[1].split(/\r?\n/)) {
    if (/^\s*$/.test(line) || /^\s*#/.test(line)) continue;
    const kv = line.match(/^([A-Za-z_][A-Za-z0-9_-]*):(?:\s+(.*)|\s*)$/);
    if (kv) {
      key = kv[1];
      if (Object.hasOwn(o, key)) throw new Error(`duplicate key ${key}`);
      let v = (kv[2] || '').trim();
      if (/^[>|][-+]?$/.test(v)) v = '';
      o[key] = v.replace(/^'(.*)'$/, '$1').replace(/^"(.*)"$/, '$1');
    } else if (key && /^\s+\S/.test(line)) {
      o[key] = `${o[key]} ${line.trim()}`.trim();
    } else {
      throw new Error('unparseable line');
    }
  }
  return o;
}

function resolveRoot(flag) {
  const raw = flag || process.env.THUNDERSTONE_SKILLS_ROOT || DEFAULT_ROOT;
  try { return realpathSync(resolve(raw)); } catch { fail(`root not found: ${raw}`); }
}

const inside = (root, p) => p === root || p.startsWith(root + sep);

// Verify one SKILL.md. Returns {item} or {skip: reason} or {private: true}.
function loadSkill(root, file) {
  let real;
  try {
    const st = lstatSync(file);
    if (st.isSymbolicLink() || !st.isFile()) return {skip: 'not a regular file'};
    if (st.size > MAX_BYTES) return {skip: 'too large'};
    real = realpathSync(file);
  } catch { return {skip: 'unreadable'}; }
  if (real !== resolve(file) || !inside(root, real)) return {skip: 'outside root'};
  if (basename(real) !== 'SKILL.md' || dirname(real) === root) return {skip: 'not <id>/SKILL.md'};
  const id = basename(dirname(real));
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)) return {skip: 'bad id'};
  let o;
  try { o = parseFrontmatter(readFileSync(real, 'utf8')); } catch (e) { return {skip: e.message}; }
  const scope = Object.hasOwn(o, 'scope') ? o.scope.trim().toLowerCase() : 'shared';
  if (scope === 'private') return {private: true, id};
  if (scope !== 'shared') return {skip: 'unknown scope'};
  const description = (o.description || '').replace(/\s+/g, ' ').trim();
  if (!description) return {skip: 'no description'};
  if (SECRETISH.test(description)) return {skip: 'secret-like description'};
  const tags = String(o.tags || '').replace(/[[\]'"]/g, '').split(/[,\s]+/).filter(Boolean);
  return {item: {
    id, kind: 'skill', description: description.slice(0, 300), path: real, tags, scope: 'shared',
    cost: COST.skill, kw: toks(`${id.replace(/-/g, ' ')} ${description} ${tags.join(' ')}`),
  }};
}

function walk(dir, depth, out) {
  if (depth > MAX_DEPTH) return;
  let entries;
  try {
    entries = readdirSync(dir, {withFileTypes: true});
  } catch (e) {
    // Root must be readable (exit 2). A sealed subdirectory is a skip, not a crash.
    if (depth === 0) fail(`unreadable root: ${e.message}`);
    out.skipped.push('unreadable dir');
    return;
  }
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name.startsWith('.')) continue;
    const p = join(dir, e.name);
    if (e.isSymbolicLink()) { out.skipped.push('symlink'); continue; }
    if (e.isDirectory()) walk(p, depth + 1, out);
    else if (e.isFile() && e.name === 'SKILL.md') out.files.push(p);
  }
}

function gen(root) {
  const found = {files: [], skipped: []};
  walk(root, 0, found);
  found.files.sort();
  const items = new Map();
  const denied = new Set();
  const stats = {private: 0, skipped: found.skipped.length, reasons: [...found.skipped]};
  for (const f of found.files) {
    const r = loadSkill(root, f);
    if (r.private) { stats.private++; denied.add(r.id); continue; }
    if (r.skip) { stats.skipped++; stats.reasons.push(r.skip); continue; }
    if (!items.has(r.item.id)) items.set(r.item.id, r.item); // first sorted path wins
  }
  for (const id of denied) items.delete(id); // a private id never has a public twin
  const list = [...items.values()].sort((a, b) => a.id.localeCompare(b.id));
  return {catalog: {version: 1, generated: new Date().toISOString(), items: list}, stats};
}

function renderLlms(items) {
  const lines = ['# Thunderstone catalog', '> Pick with: scripts/select.sh "<task>" ; load only the SKILL.md you pick.', '## Skills'];
  for (const it of items) {
    if (it.scope !== 'shared') continue;
    const d = it.description.length > 120 ? `${it.description.slice(0, 117)}...` : it.description;
    lines.push(`- [${it.id}](${it.path}): ${d} [${it.cost}]`);
  }
  return `${lines.join('\n')}\n`;
}

function flags(args, spec) {
  const f = {}; const pos = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (spec[a] === 'bool') f[a] = true;
    else if (spec[a] === 'val') { if (i + 1 >= args.length) fail(`${a} needs a value`); f[a] = args[++i]; }
    else if (a.startsWith('--')) fail(`unknown flag ${a}`);
    else pos.push(a);
  }
  return {f, pos};
}

function cmdGen(args) {
  const {f, pos} = flags(args, {'--root': 'val', '--out': 'val', '--verbose': 'bool'});
  if (pos.length) fail('gen takes no positional arguments; use --root DIR (one canonical root only)');
  const root = resolveRoot(f['--root']);
  const {catalog, stats} = gen(root);
  const json = JSON.stringify(catalog, null, 1);
  if (f['--out']) {
    mkdirSync(f['--out'], {recursive: true});
    writeFileSync(join(f['--out'], 'catalog.json'), `${json}\n`);
    writeFileSync(join(f['--out'], 'llms.txt'), renderLlms(catalog.items));
  } else console.log(json);
  if (stats.skipped) console.error(`catalog: skipped ${stats.skipped} item(s)${f['--verbose'] ? `: ${stats.reasons.join(', ')}` : ' (use --verbose for reasons)'}`);
  if (f['--verbose'] && stats.private) console.error(`catalog: ${stats.private} private item(s) withheld`);
}

function cmdSelect(args) {
  const {f, pos} = flags(args, {'--kind': 'val', '--top': 'val', '--json': 'bool', '--root': 'val'});
  if (pos.length !== 2) fail('usage: select CATALOG "task" [--kind skill] [--top N] [--json] [--root DIR]');
  const kind = f['--kind'] || null;
  if (kind && !KINDS.includes(kind) && !['agent', 'plugin'].includes(kind)) fail(`bad --kind ${kind}`);
  const top = f['--top'] === undefined ? 3 : Number(f['--top']);
  if (!Number.isInteger(top) || top < 1 || top > 20) fail('--top must be an integer 1-20');
  const root = resolveRoot(f['--root']);
  let cat;
  try { cat = JSON.parse(readFileSync(pos[0], 'utf8')); } catch { fail(`cannot read catalog ${pos[0]}`); }
  if (!cat || !Array.isArray(cat.items)) fail('catalog has no items array');
  const items = cat.items.filter(it => it && it.scope === 'shared' && typeof it.id === 'string'
    && Array.isArray(it.kw) && Array.isArray(it.tags) && typeof it.path === 'string');
  const q = toks(pos[1]);
  const N = items.length; const df = {};
  for (const it of items) for (const w of it.kw) df[w] = (df[w] || 0) + 1;
  const res = [];
  for (const it of items) {
    if (kind && it.kind !== kind) continue;
    let s = 0; const hit = [];
    for (const w of q) {
      if (it.kw.includes(w)) { s += Math.log(1 + N / df[w]); hit.push(w); }
      if (it.id.includes(w)) s += 2;
      if (it.tags.includes(w)) s += 1.5;
    }
    if (s > 0) res.push({id: it.id, kind: it.kind, score: +s.toFixed(2), cost: it.cost, path: it.path, hit});
  }
  res.sort((x, y) => y.score - x.score || x.id.localeCompare(y.id));
  // Re-verify against disk in score order: stale catalog, private flip, or out-of-root path => drop.
  const out = [];
  for (const r of res) {
    if (out.length >= top) break;
    const v = loadSkill(root, r.path);
    if (v.item && v.item.id === r.id) out.push(r);
  }
  if (!out.length) process.exitCode = 1;
  if (f['--json']) console.log(JSON.stringify(out));
  else if (!out.length) console.log('NO_MATCH');
  else for (const r of out) console.log([r.score, r.kind, r.id, r.cost, r.path, r.hit.join(',')].join('\t'));
}

{
  const [cmd, ...rest] = process.argv.slice(2);
  if (cmd === 'gen') cmdGen(rest);
  else if (cmd === 'select') cmdSelect(rest);
  else fail('usage: catalog.mjs gen [--root DIR] [--out DIR] | select CATALOG "task" [--kind k] [--top N] [--json] [--root DIR]');
}
