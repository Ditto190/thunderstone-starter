#!/usr/bin/env node
/**
 * Equip rampstackco/claude-skills (Codex/Agent port) into user-global skill roots.
 *
 * Usage:
 *   node scripts/equip-rampstack-skills.mjs [options]
 *
 * Options:
 *   --source <dir>   Path to dist/codex/.agents/skills (default: explore clone)
 *   --agents <dir>   ~/.agents/skills destination
 *   --cursor <dir>   ~/.cursor/skills destination
 *   --receipt <file> Install receipt JSON path (default: catalogue/rampstack.install.json)
 *   --force          Overwrite house / protected personal Cursor skills
 *   --dry-run        Report actions without writing
 *   -h, --help       Show help
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import os from "node:os";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "..");

const HOUSE_SKILLS = new Set(["caveman", "caveman-setup", "lean-ctx"]);

const DEFAULT_SOURCE = path.join(
  os.homedir(),
  "projects",
  "_explore-claude-skills",
  "dist",
  "codex",
  ".agents",
  "skills",
);

const DEFAULT_AGENTS = path.join(os.homedir(), ".agents", "skills");
const DEFAULT_CURSOR = path.join(os.homedir(), ".cursor", "skills");
const DEFAULT_RECEIPT = path.join(REPO_ROOT, "catalogue", "rampstack.install.json");
const EXPECTED_SOURCE_COMMIT = "9b90db257f7395fab76ff9bfcb808456709f6af3";

function usage() {
  console.log(`Usage: node scripts/equip-rampstack-skills.mjs [options]

Install all rampstack skills from dist/codex into user-global Agent and Cursor
skill roots. House skills (caveman, caveman-setup, lean-ctx) and existing
~/.cursor/skills names outside the rampstack set are skipped unless --force.

Options:
  --source <dir>    Source skills dir (default: ${DEFAULT_SOURCE})
  --agents <dir>    Agents dest (default: ${DEFAULT_AGENTS})
  --cursor <dir>    Cursor dest (default: ${DEFAULT_CURSOR})
  --receipt <file>  Receipt path (default: catalogue/rampstack.install.json)
  --force           Overwrite protected skills
  --dry-run         Print plan only
  -h, --help        Show this help
`);
}

function parseArgs(argv) {
  const opts = {
    source: DEFAULT_SOURCE,
    agents: DEFAULT_AGENTS,
    cursor: DEFAULT_CURSOR,
    receipt: DEFAULT_RECEIPT,
    force: false,
    dryRun: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "-h" || a === "--help") opts.help = true;
    else if (a === "--force") opts.force = true;
    else if (a === "--dry-run") opts.dryRun = true;
    else if (a === "--source") opts.source = path.resolve(argv[++i] ?? "");
    else if (a === "--agents") opts.agents = path.resolve(argv[++i] ?? "");
    else if (a === "--cursor") opts.cursor = path.resolve(argv[++i] ?? "");
    else if (a === "--receipt") opts.receipt = path.resolve(argv[++i] ?? "");
    else {
      console.error(`Unknown argument: ${a}`);
      usage();
      process.exit(2);
    }
  }
  if (!opts.source || opts.source === path.resolve("")) {
    console.error("--source requires a path");
    process.exit(2);
  }
  return opts;
}

function listSkillDirs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => {
      if (d.isDirectory()) return true;
      // Windows junctions/symlinks: Dirent.isDirectory() is often false.
      if (d.isSymbolicLink()) {
        try {
          return fs.statSync(path.join(dir, d.name)).isDirectory();
        } catch {
          return false;
        }
      }
      return false;
    })
    .map((d) => d.name)
    .sort();
}

function resolveSourceCommit(sourceDir) {
  // Walk up from dist/codex/.agents/skills to the explore-repo root.
  let dir = path.resolve(sourceDir);
  for (let i = 0; i < 8; i++) {
    const gitDir = path.join(dir, ".git");
    if (fs.existsSync(gitDir)) {
      try {
        return execFileSync("git", ["rev-parse", "HEAD"], {
          cwd: dir,
          encoding: "utf8",
        }).trim();
      } catch {
        return EXPECTED_SOURCE_COMMIT;
      }
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return EXPECTED_SOURCE_COMMIT;
}

/** Receipt paths must stay portable (no C:\\Users\\... / absolute home). */
function toPortablePath(inputPath) {
  const resolved = path.resolve(inputPath);
  const home = path.resolve(os.homedir());
  const eq =
    process.platform === "win32"
      ? (a, b) => a.toLowerCase() === b.toLowerCase()
      : (a, b) => a === b;
  const underHome = (() => {
    if (eq(resolved, home)) return true;
    const prefix = home.endsWith(path.sep) ? home : home + path.sep;
    if (process.platform === "win32") {
      return resolved.toLowerCase().startsWith(prefix.toLowerCase());
    }
    return resolved.startsWith(prefix);
  })();
  if (underHome) {
    const rel = path.relative(home, resolved).split(path.sep).join("/");
    return rel ? `$HOME/${rel}` : "$HOME";
  }
  // Outside home: keep a relative note, never machine-local absolute.
  const base = path.basename(resolved);
  const parent = path.basename(path.dirname(resolved));
  return `outside-$HOME/…/${parent}/${base}`;
}

function rmrf(target) {
  fs.rmSync(target, { recursive: true, force: true });
}

function copyDir(src, dest) {
  fs.cpSync(src, dest, { recursive: true, force: true });
}

/** Prefer Windows junction; fall back to symlink; then copy. */
function linkOrCopy(canonical, linkPath) {
  if (fs.existsSync(linkPath)) rmrf(linkPath);
  const absCanonical = path.resolve(canonical);
  const absLink = path.resolve(linkPath);
  fs.mkdirSync(path.dirname(absLink), { recursive: true });

  if (process.platform === "win32") {
    try {
      execFileSync(
        "cmd",
        ["/c", "mklink", "/J", absLink, absCanonical],
        { stdio: ["ignore", "ignore", "pipe"] },
      );
      return "junction";
    } catch {
      // fall through
    }
  }

  try {
    fs.symlinkSync(absCanonical, absLink, "junction");
    return "junction";
  } catch {
    // fall through
  }

  try {
    fs.symlinkSync(absCanonical, absLink, "dir");
    return "symlink";
  } catch {
    // fall through
  }

  copyDir(absCanonical, absLink);
  return "copy";
}

function ensureEmptyDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function isProtected(name, rampstackSet, existingCursor, force) {
  if (force) return null;
  if (HOUSE_SKILLS.has(name)) return "house";
  // Personal Cursor skills outside the rampstack set: never clobber.
  // (They are not install sources; this guards accidental name collisions.)
  if (existingCursor.has(name) && !rampstackSet.has(name)) {
    return "cursor-personal";
  }
  return null;
}

function installOne(name, srcRoot, agentsRoot, cursorRoot, dryRun) {
  const src = path.join(srcRoot, name);
  const agentsDest = path.join(agentsRoot, name);
  const cursorDest = path.join(cursorRoot, name);

  if (dryRun) {
    return { agents: "would-install", cursor: "would-link-or-copy" };
  }

  ensureEmptyDir(agentsRoot);
  ensureEmptyDir(cursorRoot);

  if (fs.existsSync(agentsDest)) rmrf(agentsDest);
  copyDir(src, agentsDest);

  const linkMode = linkOrCopy(agentsDest, cursorDest);
  return { agents: "copied", cursor: linkMode };
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    usage();
    process.exit(0);
  }

  if (!fs.existsSync(opts.source)) {
    console.error(`Source not found: ${opts.source}`);
    process.exit(1);
  }

  const rampstackNames = listSkillDirs(opts.source);
  if (rampstackNames.length === 0) {
    console.error(`No skill directories in ${opts.source}`);
    process.exit(1);
  }

  const rampstackSet = new Set(rampstackNames);
  const existingCursor = new Set(listSkillDirs(opts.cursor));
  const sourceCommit = resolveSourceCommit(opts.source);

  const skipped = [];
  const installed = [];
  let agentsInstalled = 0;
  let cursorInstalled = 0;
  const linkModes = { junction: 0, symlink: 0, copy: 0 };

  for (const name of rampstackNames) {
    const reason = isProtected(name, rampstackSet, existingCursor, opts.force);
    if (reason) {
      skipped.push({ name, reason });
      continue;
    }

    const result = installOne(
      name,
      opts.source,
      opts.agents,
      opts.cursor,
      opts.dryRun,
    );
    installed.push({ name, ...result });
    agentsInstalled += 1;
    cursorInstalled += 1;
    if (result.cursor in linkModes) linkModes[result.cursor] += 1;
  }

  // Preserve note: personal ~/.cursor/skills outside rampstackSet are untouched
  // (installer only writes rampstack names).

  const receipt = {
    installedAt: new Date().toISOString(),
    sourceCommit,
    sourcePath: toPortablePath(opts.source),
    count: installed.length,
    expectedCount: rampstackNames.length,
    agentsRoot: toPortablePath(opts.agents),
    cursorRoot: toPortablePath(opts.cursor),
    agentsInstalled,
    cursorInstalled,
    linkModes,
    skipped,
    dryRun: opts.dryRun,
    force: opts.force,
  };

  if (!opts.dryRun) {
    fs.mkdirSync(path.dirname(opts.receipt), { recursive: true });
    fs.writeFileSync(opts.receipt, `${JSON.stringify(receipt, null, 2)}\n`, "utf8");
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        agentsInstalled,
        cursorInstalled,
        skipped: skipped.map((s) => s.name),
        skippedDetail: skipped,
        receipt: opts.dryRun ? null : opts.receipt,
        sourceCommit,
        linkModes,
        dryRun: opts.dryRun,
      },
      null,
      2,
    ),
  );

  // Plan notes equip may call gen-skills-catalog — owned by another agent; skip.
}

main();
