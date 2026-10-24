#!/usr/bin/env node
/**
 * Score catalogue skills against a context string. No network / no LLM.
 * Usage: node scripts/suggest-skills.mjs "<context>" [--top N] [--json]
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const INDEX = join(ROOT, "catalogue", "skills.index.json");

const args = process.argv.slice(2);
const jsonOut = args.includes("--json");
const topIdx = args.indexOf("--top");
const topN = topIdx >= 0 ? Math.max(1, Number(args[topIdx + 1]) || 5) : 5;
const contextParts = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--json") continue;
  if (args[i] === "--top") {
    i += 1;
    continue;
  }
  contextParts.push(args[i]);
}
const context = contextParts.join(" ").trim();

if (!context) {
  console.error('Usage: node scripts/suggest-skills.mjs "<context>" [--top N] [--json]');
  process.exit(2);
}

if (!existsSync(INDEX)) {
  console.error("suggest-skills: missing catalogue/skills.index.json — run gen-skills-catalog.mjs");
  process.exit(2);
}

const index = JSON.parse(readFileSync(INDEX, "utf8"));
const skills = index.skills || [];

function tokens(s) {
  return String(s || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1);
}

const query = tokens(context);
const querySet = new Set(query);

// Light stopwords so "the/for/with" do not dominate
const STOP = new Set([
  "the",
  "and",
  "for",
  "with",
  "from",
  "this",
  "that",
  "into",
  "onto",
  "your",
  "use",
  "using",
  "when",
  "want",
  "need",
  "help",
  "run",
  "make",
]);

function scoreSkill(skill) {
  const hay = [
    skill.name,
    skill.catalog_summary,
    skill.category,
    ...(skill.triggers || []),
  ]
    .join(" ")
    .toLowerCase();
  const nameToks = tokens(skill.name.replace(/-/g, " "));
  let score = 0;
  const why = [];

  for (const t of query) {
    if (STOP.has(t)) continue;
    if (skill.name === t || skill.name.includes(t)) {
      score += 8;
      why.push(`name:${t}`);
      continue;
    }
    if (nameToks.includes(t)) {
      score += 6;
      why.push(`name-token:${t}`);
      continue;
    }
    if ((skill.triggers || []).some((tr) => tr.includes(t) || t.includes(tr))) {
      score += 5;
      why.push(`trigger:${t}`);
      continue;
    }
    if (hay.includes(t)) {
      score += 2;
      why.push(`summary:${t}`);
    }
  }

  // Phrase boost: multi-word query substrings in summary/name
  const phrase = context.toLowerCase();
  if (skill.name.replace(/-/g, " ") && phrase.includes(skill.name.replace(/-/g, " "))) {
    score += 10;
    why.push("phrase:name");
  }
  if (skill.catalog_summary && phrase.includes(skill.catalog_summary.toLowerCase())) {
    score += 4;
  }

  // Prefer exact WCAG / a11y style overlaps
  for (const t of querySet) {
    if (t === "wcag" || t === "a11y" || t === "accessibility") {
      if (hay.includes(t) || skill.name.includes("accessibility")) {
        score += 4;
        why.push(`boost:${t}`);
      }
    }
  }

  return { skill, score, why: [...new Set(why)].slice(0, 6) };
}

const ranked = skills
  .map(scoreSkill)
  .filter((r) => r.score > 0)
  .sort((a, b) => b.score - a.score || a.skill.name.localeCompare(b.skill.name))
  .slice(0, topN);

if (jsonOut) {
  console.log(
    JSON.stringify(
      {
        query: context,
        results: ranked.map((r) => ({
          id: r.skill.id,
          name: r.skill.name,
          catalog_summary: r.skill.catalog_summary,
          category: r.skill.category,
          path: r.skill.path,
          source: r.skill.source,
          score: r.score,
          why: r.why,
        })),
      },
      null,
      2,
    ),
  );
} else {
  if (ranked.length === 0) {
    console.log("No matching skills.");
    process.exit(0);
  }
  for (const r of ranked) {
    console.log(
      `${r.skill.name}\t${r.score}\t${r.skill.catalog_summary}\t${r.why.join(",")}`,
    );
  }
}
