#!/usr/bin/env node
/** Skills catalogue invariants: --check, lock↔index, collections ⊆ index, suggest smoke. */
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
process.chdir(root);

function runNode(args) {
  const r = spawnSync(process.execPath, args, { encoding: "utf8", cwd: root });
  if (r.status !== 0) {
    process.stderr.write(r.stderr || r.stdout || `exit ${r.status}\n`);
    process.exit(r.status || 1);
  }
  return r.stdout;
}

runNode(["scripts/gen-skills-catalog.mjs", "--check"]);

const index = JSON.parse(readFileSync("catalogue/skills.index.json", "utf8"));
const lock = JSON.parse(readFileSync("catalogue/skills.lock.json", "utf8"));
const byCat = JSON.parse(readFileSync("catalogue/skills.by_category.json", "utf8"));
const cols = [
  "catalogue/collections/rampstack-full.json",
  "catalogue/collections/rampstack-starter.json",
  "catalogue/collections/thunderstone-house.json",
].map((p) => JSON.parse(readFileSync(p, "utf8")));

const indexNames = new Set(index.skills.map((s) => s.name));
const lockNames = Object.keys(lock).filter(
  (k) => k !== "generatedAt" && k !== "sourceRootHint",
);
if (lockNames.length !== indexNames.size) {
  console.error(`lock/index size mismatch: ${lockNames.length} vs ${indexNames.size}`);
  process.exit(1);
}
for (const n of lockNames) {
  if (!indexNames.has(n)) {
    console.error(`lock name missing from index: ${n}`);
    process.exit(1);
  }
  if (!lock[n]["SKILL.md"]) {
    console.error(`lock missing SKILL.md hash: ${n}`);
    process.exit(1);
  }
}

for (const col of cols) {
  for (const id of col.skills) {
    if (!indexNames.has(id)) {
      console.error(`collection ${col.id} unknown id: ${id}`);
      process.exit(1);
    }
  }
}

const catNames = new Set(Object.values(byCat).flat());
for (const n of indexNames) {
  if (!catNames.has(n)) {
    console.error(`by_category missing: ${n}`);
    process.exit(1);
  }
}

function expandPath(p) {
  if (p.startsWith("~/")) return join(homedir(), p.slice(2));
  return join(root, p);
}

let resolvable = 0;
for (const s of index.skills) {
  const abs = expandPath(s.path);
  const house = join(root, ".agents", "skills", s.name, "SKILL.md");
  const explore = join(
    root,
    "..",
    "_explore-claude-skills",
    "dist",
    "codex",
    ".agents",
    "skills",
    s.name,
    "SKILL.md",
  );
  if (existsSync(abs) || existsSync(house) || existsSync(explore)) resolvable += 1;
}
if (resolvable === 0) {
  console.error("no SKILL.md paths resolvable");
  process.exit(1);
}

const smoke = JSON.parse(
  runNode([
    "scripts/suggest-skills.mjs",
    "WCAG accessibility audit",
    "--json",
    "--top",
    "3",
  ]),
);
const top = smoke.results?.[0]?.name;
if (top !== "accessibility-audit") {
  console.error(`suggest smoke expected accessibility-audit, got: ${top}`);
  process.exit(1);
}

console.log(`skills-catalog test ok (${index.count} skills, ${resolvable} resolvable)`);
