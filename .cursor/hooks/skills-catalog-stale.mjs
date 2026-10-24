#!/usr/bin/env node
/**
 * sessionStart: detect skills catalogue drift vs on-disk skill trees.
 * Detect + nudge only (failClosed false). Never rewrites catalogue.
 */
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const hooksDir = dirname(fileURLToPath(import.meta.url));
const root = join(hooksDir, "../..");
const lockPath = join(root, "catalogue", "skills.lock.json");
const houseRoot = join(root, ".agents", "skills");
const globalAgents = join(homedir(), ".agents", "skills");
const globalCursor = join(homedir(), ".cursor", "skills");

function emit(ctx) {
  if (!ctx) {
    process.stdout.write("{}\n");
    return;
  }
  process.stdout.write(`${JSON.stringify({ additional_context: ctx })}\n`);
}

function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function resolveSkillMd(name) {
  const candidates = [
    join(houseRoot, name, "SKILL.md"),
    process.env.RAMPSTACK_SKILLS_ROOT
      ? join(process.env.RAMPSTACK_SKILLS_ROOT, name, "SKILL.md")
      : null,
    join(globalAgents, name, "SKILL.md"),
    join(globalCursor, name, "SKILL.md"),
  ].filter(Boolean);
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

try {
  if (!existsSync(lockPath)) {
    emit("CATALOG_STALE: missing catalogue/skills.lock.json — run node scripts/gen-skills-catalog.mjs");
    process.exit(0);
  }

  const lock = JSON.parse(readFileSync(lockPath, "utf8"));
  const names = Object.keys(lock).filter(
    (k) => k !== "generatedAt" && k !== "sourceRootHint" && lock[k]?.["SKILL.md"],
  );

  let checked = 0;
  let mismatched = 0;
  for (const name of names) {
    const path = resolveSkillMd(name);
    if (!path) continue; // not installed yet — equip owns that; skip
    checked += 1;
    const want = lock[name]["SKILL.md"];
    const got = sha256File(path);
    if (got !== want) mismatched += 1;
    // Cap work for sessionStart budget
    if (checked >= 40 && mismatched === 0) break;
    if (mismatched >= 3) break;
  }

  if (mismatched > 0) {
    emit(
      `CATALOG_STALE: ${mismatched} skill hash drift — run node scripts/gen-skills-catalog.mjs`,
    );
  } else {
    emit(null);
  }
} catch {
  // fail-open
  emit(null);
}
process.exit(0);
