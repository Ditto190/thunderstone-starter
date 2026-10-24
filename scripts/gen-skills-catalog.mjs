#!/usr/bin/env node
/**
 * Build thunderstone skills catalogue (metadata only) from rampstack + house skills.
 * Default: --write. Use --check to exit 1 when tracked catalogue drifts.
 * Never overwrites catalogue/rampstack.install.json (equip owns it).
 */
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const CATALOGUE = join(ROOT, "catalogue");
const HOUSE_SKILLS = join(ROOT, ".agents", "skills");

/** Upstream Codex port used for first catalog write / local regen. */
const DEFAULT_RAMPSTACK = resolve(
  ROOT,
  "..",
  "_explore-claude-skills",
  "dist",
  "codex",
  ".agents",
  "skills",
);

/** Curated subset matching rampstackco/claude-skills-starter. */
const RAMPSTACK_STARTER = [
  "accessibility-audit",
  "code-review-web",
  "content-and-copy",
  "content-strategy",
  "cro-optimization",
  "design-standards",
  "frontend-component-build",
  "performance-optimization",
  "pm-spec-writing",
  "qa-testing",
  "seo-aeo-geo",
  "seo-keyword",
  "seo-onpage",
  "skill-creation-walkthrough",
];

const args = process.argv.slice(2);
const checkOnly = args.includes("--check");
const write = !checkOnly; // --write is default

function flagValue(name) {
  const i = args.indexOf(name);
  if (i === -1) return null;
  return args[i + 1] ?? null;
}

const rampstackRoot =
  flagValue("--source") ||
  process.env.RAMPSTACK_SKILLS_ROOT ||
  (existsSync(DEFAULT_RAMPSTACK) ? DEFAULT_RAMPSTACK : null) ||
  (existsSync(join(homedir(), ".agents", "skills"))
    ? join(homedir(), ".agents", "skills")
    : null);

function sha256(buf) {
  return createHash("sha256").update(buf).digest("hex");
}

function parseFrontmatter(text) {
  if (!text.startsWith("---")) return {};
  const end = text.indexOf("\n---", 3);
  if (end === -1) return {};
  const block = text.slice(3, end).replace(/^\r?\n/, "");
  const out = {};
  let key = null;
  let buf = [];
  const flush = () => {
    if (!key) return;
    let v = buf.join("\n").trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    out[key] = v.replace(/\\n/g, "\n").replace(/\\"/g, '"');
    key = null;
    buf = [];
  };
  for (const line of block.split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (m && !line.startsWith(" ") && !line.startsWith("\t")) {
      flush();
      key = m[1];
      const rest = m[2];
      if (rest === ">-" || rest === ">" || rest === "|") {
        buf = [];
        out[key] = "";
      } else if (rest === "") {
        buf = [];
      } else {
        buf = [rest];
      }
      continue;
    }
    if (key && (line.startsWith("  ") || line.startsWith("\t") || line === "")) {
      buf.push(line.replace(/^\s{2}/, "").trimEnd());
    }
  }
  flush();
  for (const k of Object.keys(out)) {
    if (typeof out[k] === "string") out[k] = out[k].replace(/\s+/g, " ").trim();
  }
  return out;
}

function parseSidecar(skillDir) {
  const p = join(skillDir, "references", "_claude-frontmatter-extras.yaml");
  if (!existsSync(p)) return {};
  const text = readFileSync(p, "utf8");
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^(category|catalog_summary|display_order):\s*(.*)$/);
    if (!m) continue;
    let v = m[2].trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    out[m[1]] = v;
  }
  return out;
}

function extractTriggers(description) {
  if (!description) return [];
  const m = description.match(/Triggers on ([^.]+)\.?/i);
  const raw = m ? m[1] : description;
  return raw
    .split(/,|\band\b/i)
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 2 && s.length < 48)
    .slice(0, 12);
}

function summaryFromDescription(description) {
  if (!description) return "";
  const first = description.split(/\.(\s|$)/)[0].trim();
  return first.length > 140 ? `${first.slice(0, 137)}...` : first;
}

function listSkillDirs(root) {
  if (!root || !existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .filter((name) => existsSync(join(root, name, "SKILL.md")))
    .sort();
}

function loadSkill(name, skillDir, source) {
  const skillPath = join(skillDir, "SKILL.md");
  const body = readFileSync(skillPath);
  const text = body.toString("utf8");
  const fm = parseFrontmatter(text);
  const side = parseSidecar(skillDir);
  const skillName = fm.name || name;
  const description = fm.description || "";
  const catalog_summary =
    side.catalog_summary || summaryFromDescription(description);
  const category =
    side.category || (source === "thunderstone" ? "thunderstone" : "uncategorized");
  const updated = new Date(statSync(skillPath).mtimeMs).toISOString().slice(0, 10);
  const path =
    source === "thunderstone"
      ? `.agents/skills/${skillName}/SKILL.md`
      : `~/.agents/skills/${skillName}/SKILL.md`;
  return {
    id: skillName,
    kind: "skill",
    name: skillName,
    catalog_summary,
    category,
    triggers: extractTriggers(description),
    description,
    path,
    source,
    status: "live",
    updated,
    sha256: sha256(body),
  };
}

function buildCatalogue() {
  const byName = new Map();

  if (rampstackRoot) {
    for (const name of listSkillDirs(rampstackRoot)) {
      const skill = loadSkill(name, join(rampstackRoot, name), "rampstack");
      byName.set(skill.name, skill);
    }
  }

  for (const name of listSkillDirs(HOUSE_SKILLS)) {
    const skill = loadSkill(name, join(HOUSE_SKILLS, name), "thunderstone");
    byName.set(skill.name, skill); // house overrides
  }

  const skills = [...byName.values()].sort((a, b) => a.name.localeCompare(b.name));
  const generatedAt = new Date().toISOString();

  const index = {
    generatedAt,
    count: skills.length,
    skills: skills.map(
      ({
        id,
        kind,
        name,
        catalog_summary,
        category,
        triggers,
        path,
        source,
        status,
        updated,
      }) => ({
        id,
        kind,
        name,
        catalog_summary,
        category,
        triggers,
        path,
        source,
        status,
        updated,
      }),
    ),
  };

  const lock = {
    generatedAt,
    sourceRootHint: rampstackRoot
      ? relative(ROOT, rampstackRoot).replace(/\\/g, "/") || null
      : null,
  };
  for (const s of skills) {
    lock[s.name] = { "SKILL.md": s.sha256 };
  }

  const byCategory = {};
  for (const s of skills) {
    if (!byCategory[s.category]) byCategory[s.category] = [];
    byCategory[s.category].push(s.name);
  }
  for (const k of Object.keys(byCategory)) byCategory[k].sort();

  const llmsLines = [
    "# Thunderstone skills catalogue (metadata)",
    `# generatedAt: ${generatedAt}`,
    `# count: ${skills.length}`,
    '# Load this or run: node scripts/suggest-skills.mjs "<task>"',
    "# Then Read the selected SKILL.md on demand (global or .agents/skills).",
    "",
  ];
  for (const s of skills) {
    llmsLines.push(`${s.name} — ${s.catalog_summary}`);
  }
  const llmsTxt = `${llmsLines.join("\n")}\n`;

  const rampNames = skills.filter((s) => s.source === "rampstack").map((s) => s.name);
  const houseNames = skills
    .filter((s) => s.source === "thunderstone")
    .map((s) => s.name);
  const starterIds = RAMPSTACK_STARTER.filter((id) => byName.has(id));

  const collections = {
    "rampstack-full": {
      id: "rampstack-full",
      name: "Rampstack full",
      description: "All rampstack skills in the catalogue (excludes house-only overrides).",
      skills: rampNames,
    },
    "rampstack-starter": {
      id: "rampstack-starter",
      name: "Rampstack starter",
      description:
        "Curated subset matching rampstackco/claude-skills-starter (brand/SEO/PM/dev core).",
      skills: starterIds,
    },
    "thunderstone-house": {
      id: "thunderstone-house",
      name: "Thunderstone house",
      description: "Project .agents/skills overrides only.",
      skills: houseNames,
    },
  };

  return { index, lock, byCategory, llmsTxt, collections, skills };
}

function stableStringify(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

function readText(path) {
  return existsSync(path) ? readFileSync(path, "utf8") : null;
}

function expectedFiles(built) {
  return {
    "skills.index.json": stableStringify(built.index),
    "skills.lock.json": stableStringify(built.lock),
    "skills.by_category.json": stableStringify(built.byCategory),
    "llms.txt": built.llmsTxt,
    "collections/rampstack-full.json": stableStringify(built.collections["rampstack-full"]),
    "collections/rampstack-starter.json": stableStringify(
      built.collections["rampstack-starter"],
    ),
    "collections/thunderstone-house.json": stableStringify(
      built.collections["thunderstone-house"],
    ),
  };
}

/** Drop volatile fields so --check is stable across regenerations with identical bodies. */
function normalizeForCheck(text, rel) {
  if (rel.endsWith(".txt")) {
    return text
      .split(/\r?\n/)
      .filter((l) => !l.startsWith("# generatedAt:"))
      .join("\n");
  }
  try {
    const obj = JSON.parse(text);
    if (obj && typeof obj === "object") {
      delete obj.generatedAt;
      delete obj.sourceRootHint;
    }
    return JSON.stringify(obj);
  } catch {
    return text;
  }
}

function structuralCheckFromDisk() {
  let drift = 0;
  const required = [
    "skills.index.json",
    "skills.lock.json",
    "skills.by_category.json",
    "llms.txt",
    "collections/rampstack-full.json",
    "collections/rampstack-starter.json",
    "collections/thunderstone-house.json",
  ];
  for (const rel of required) {
    if (!existsSync(join(CATALOGUE, rel))) {
      console.error(`missing: catalogue/${rel}`);
      drift = 1;
    }
  }
  if (drift) return drift;

  const index = JSON.parse(readFileSync(join(CATALOGUE, "skills.index.json"), "utf8"));
  const lock = JSON.parse(readFileSync(join(CATALOGUE, "skills.lock.json"), "utf8"));
  const lockNames = Object.keys(lock)
    .filter((k) => k !== "generatedAt" && k !== "sourceRootHint")
    .sort();
  const indexNames = (index.skills || []).map((s) => s.name).sort();
  if (lockNames.join("\0") !== indexNames.join("\0")) {
    console.error("drift: lock name set ≠ index name set");
    drift = 1;
  }
  for (const rel of [
    "collections/rampstack-full.json",
    "collections/rampstack-starter.json",
    "collections/thunderstone-house.json",
  ]) {
    const col = JSON.parse(readFileSync(join(CATALOGUE, rel), "utf8"));
    for (const id of col.skills || []) {
      if (!indexNames.includes(id)) {
        console.error(`collection ${col.id} has unknown id: ${id}`);
        drift = 1;
      }
    }
  }
  if (!drift) {
    console.log(
      `skills-catalog check ok (structural; ${index.count ?? indexNames.length} skills; no full source for regen)`,
    );
  }
  return drift;
}

function main() {
  const explicitSource = Boolean(flagValue("--source") || process.env.RAMPSTACK_SKILLS_ROOT);
  const rampCount = listSkillDirs(rampstackRoot).length;
  const canRegenDrift = rampCount >= 50 || (explicitSource && rampCount > 0);

  if (checkOnly && !canRegenDrift) {
    if (!existsSync(join(CATALOGUE, "skills.index.json"))) {
      console.error(
        "gen-skills-catalog --check: catalogue missing and no rampstack source.\n" +
          "Pass --source <dir> or set RAMPSTACK_SKILLS_ROOT.",
      );
      process.exit(2);
    }
    const drift = structuralCheckFromDisk();
    if (drift) {
      console.error("CATALOG_STALE: run node scripts/gen-skills-catalog.mjs");
      process.exit(1);
    }
    return;
  }

  if (!rampstackRoot && listSkillDirs(HOUSE_SKILLS).length === 0) {
    console.error(
      "gen-skills-catalog: no rampstack source and no house skills found.\n" +
        "Pass --source <dir> or set RAMPSTACK_SKILLS_ROOT.",
    );
    process.exit(2);
  }

  const built = buildCatalogue();
  const files = expectedFiles(built);

  if (checkOnly) {
    let drift = 0;
    for (const [rel, content] of Object.entries(files)) {
      const path = join(CATALOGUE, rel);
      const onDisk = readText(path);
      if (onDisk === null) {
        console.error(`missing: catalogue/${rel}`);
        drift = 1;
        continue;
      }
      if (normalizeForCheck(onDisk, rel) !== normalizeForCheck(content, rel)) {
        console.error(`drift: catalogue/${rel}`);
        drift = 1;
      }
    }
    const index = built.index;
    const lockNames = Object.keys(built.lock)
      .filter((k) => k !== "generatedAt" && k !== "sourceRootHint")
      .sort();
    const indexNames = index.skills.map((s) => s.name).sort();
    if (lockNames.join("\0") !== indexNames.join("\0")) {
      console.error("drift: lock name set ≠ index name set");
      drift = 1;
    }
    for (const col of Object.values(built.collections)) {
      for (const id of col.skills) {
        if (!index.skills.some((s) => s.id === id)) {
          console.error(`collection ${col.id} has unknown id: ${id}`);
          drift = 1;
        }
      }
    }
    if (drift) {
      console.error("CATALOG_STALE: run node scripts/gen-skills-catalog.mjs");
      process.exit(1);
    }
    console.log(`skills-catalog check ok (${index.count} skills)`);
    return;
  }

  if (write) {
    mkdirSync(join(CATALOGUE, "collections"), { recursive: true });
    for (const [rel, content] of Object.entries(files)) {
      const path = join(CATALOGUE, rel);
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, content, "utf8");
    }
    // Never overwrite catalogue/rampstack.install.json (equip owns it).
    console.log(
      `wrote catalogue (${built.index.count} skills; rampstack=${built.collections["rampstack-full"].skills.length}; house=${built.collections["thunderstone-house"].skills.length}; starter=${built.collections["rampstack-starter"].skills.length})`,
    );
  }
}

main();
