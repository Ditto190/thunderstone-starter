#!/usr/bin/env node
/**
 * Run a project .sh hook without a visible Windows console.
 * Cursor on Windows often file-associates bare .sh → git-bash/mintty (focus steal)
 * or opens the script in the editor when the shebang is missing.
 */
import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptRel = process.argv[2];
if (!scriptRel) {
  console.error("usage: node run-hook.mjs <relative-or-absolute-script.sh>");
  process.exit(1);
}

const hooksDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(hooksDir, "../..");
const scriptPath = resolve(repoRoot, scriptRel);

function bashCandidates() {
  const out = [];
  if (process.env.CURSOR_HOOK_BASH) out.push(process.env.CURSOR_HOOK_BASH);
  out.push("bash");
  if (process.env.ProgramFiles) {
    out.push(join(process.env.ProgramFiles, "Git", "bin", "bash.exe"));
  }
  const pf86 = process.env["ProgramFiles(x86)"];
  if (pf86) out.push(join(pf86, "Git", "bin", "bash.exe"));
  return out;
}

function findBash() {
  for (const candidate of bashCandidates()) {
    if (candidate === "bash") {
      const probe = spawnSync(candidate, ["-c", ":"], {
        windowsHide: true,
        timeout: 5000,
      });
      if (!probe.error) return candidate;
      continue;
    }
    if (existsSync(candidate)) return candidate;
  }
  return "bash";
}

const bash = findBash();
const child = spawn(bash, [scriptPath], {
  cwd: repoRoot,
  env: process.env,
  stdio: ["pipe", "pipe", "pipe"],
  windowsHide: true,
  shell: false,
});

process.stdin.pipe(child.stdin);
child.stdout.pipe(process.stdout);
child.stderr.pipe(process.stderr);

child.on("error", (err) => {
  console.error(`run-hook: failed to spawn ${bash}: ${err.message}`);
  process.exit(0); // fail-open for advisory hooks
});

child.on("close", (code, signal) => {
  if (signal) process.exit(1);
  process.exit(code ?? 0);
});
