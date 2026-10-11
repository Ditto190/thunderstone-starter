import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { parseEnv } from "node:util";

const argv = process.argv.slice(2);
let only = null;
if (argv[0] === "--only") {
  const list = argv[1];
  if (!list || list.startsWith("-") || !argv[2]) {
    throw new Error("Usage: node scripts/env-run.mjs [--only KEY,KEY] <command> [args...]");
  }
  only = new Set(list.split(",").map((key) => key.trim()).filter(Boolean));
  argv.splice(0, 2);
}
const [command, ...args] = argv;
if (!command) throw new Error("Usage: node scripts/env-run.mjs [--only KEY,KEY] <command> [args...]");

const env = { ...process.env };
for (const path of [
  "/run/secrets/thunderstone.env",
  resolve(homedir(), ".config/thunderstone/env"),
  resolve(".env.local"),
  resolve(".env.defaults"),
]) {
  if (!existsSync(path)) continue;
  let values;
  try {
    values = parseEnv(readFileSync(path, "utf8"));
  } catch {
    throw new Error(`Environment parsing failed for ${path}`);
  }
  for (const [key, value] of Object.entries(values)) {
    if (key in env) continue;
    if (only && !only.has(key)) continue;
    env[key] = value;
  }
}
const result = spawnSync(command, args, { env, stdio: "inherit" });
if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status ?? 1);
