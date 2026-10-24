#!/usr/bin/env node
/**
 * beforeShellExecution gate for git commit / checkpoint.
 * Runs check-hygiene before allowing the agent to commit.
 * Fail-open only after all bash candidates miss so a broken
 * hook never bricks the shell; Windows must still find Git Bash.
 */
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const hooksDir = dirname(fileURLToPath(import.meta.url));
const root = join(hooksDir, "../..");

function bashCandidates() {
  const out = [];
  // CURSOR_HOOK_BASH is handled exclusively in main — do not list it here.
  out.push("bash");
  if (process.env.ProgramFiles) {
    out.push(join(process.env.ProgramFiles, "Git", "bin", "bash.exe"));
  }
  const pf86 = process.env["ProgramFiles(x86)"];
  if (pf86) out.push(join(pf86, "Git", "bin", "bash.exe"));
  return out;
}

function runHygiene(bash) {
  return spawnSync(bash, ["scripts/check-hygiene.sh"], {
    cwd: root,
    encoding: "utf8",
    windowsHide: true,
    timeout: 15000,
  });
}

function readStdin() {
  return new Promise((resolve) => {
    const chunks = [];
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (c) => chunks.push(c));
    process.stdin.on("end", () => resolve(chunks.join("")));
    process.stdin.on("error", () => resolve(""));
    setTimeout(() => resolve(chunks.join("")), 2000);
  });
}

function allow() {
  process.stdout.write(JSON.stringify({ permission: "allow" }));
  process.exit(0);
}

function deny(userMessage, agentMessage) {
  process.stdout.write(
    JSON.stringify({
      permission: "deny",
      user_message: userMessage,
      agent_message: agentMessage,
    }),
  );
  process.exit(0);
}

const raw = await readStdin();
let input = {};
try {
  input = raw.trim() ? JSON.parse(raw) : {};
} catch {
  allow();
}

const command = String(input.command || "");
const isCommit =
  /\bgit(\.exe)?\s+commit\b/i.test(command) ||
  /\bcheckpoint\.sh\b/.test(command) ||
  /\bALLOW_LOCAL_COMMITS=1\b/.test(command);

if (!isCommit) allow();

let result = null;
const preferred = process.env.CURSOR_HOOK_BASH;
if (preferred) {
  // Explicit override: never fall through to other bash candidates.
  const attempt = runHygiene(preferred);
  if (attempt.error) {
    deny(
      `Commit blocked: CURSOR_HOOK_BASH failed to run.\n${attempt.error.message}`,
      "Fix CURSOR_HOOK_BASH or unset it so Git Bash discovery can run.",
    );
  }
  result = attempt;
} else {
  for (const bash of bashCandidates()) {
    if (bash !== "bash" && !existsSync(bash)) continue;
    const attempt = runHygiene(bash);
    if (attempt.error) continue;
    result = attempt;
    break;
  }
}

if (!result) {
  // Fail-open: no bash candidate could be spawned.
  allow();
}

if (result.status === 0) allow();

const detail = (result.stderr || result.stdout || "hygiene failed")
  .trim()
  .slice(0, 500);

deny(
  `Commit blocked: hygiene check failed.\n${detail}`,
  "Run bash scripts/check-hygiene.sh, fix BLOCKER findings, then retry the commit.",
);
