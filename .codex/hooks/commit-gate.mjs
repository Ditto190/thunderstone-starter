#!/usr/bin/env node
/**
 * beforeShellExecution gate for git commit / checkpoint.
 * Runs check-hygiene before allowing the agent to commit.
 * Fail-open on spawn errors so a broken hook never bricks the shell.
 */
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const hooksDir = dirname(fileURLToPath(import.meta.url));
const root = join(hooksDir, "../..");

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

const result = spawnSync("bash", ["scripts/check-hygiene.sh"], {
  cwd: root,
  encoding: "utf8",
  windowsHide: true,
  timeout: 15000,
});

if (result.error) {
  // Fail open — hygiene runner unavailable (e.g. no bash in PATH).
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
