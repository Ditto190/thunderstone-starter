import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
const [command, ...args] = process.argv.slice(2);
if (!command) throw new Error("Usage: node scripts/env-run.mjs <command> [args...]");
const env = { ...process.env };
for (const path of [
  "/run/secrets/thunderstone.env",
  resolve(homedir(), ".config/thunderstone/env"),
  resolve(".env.local"),
  resolve(".env.defaults"),
]) {
  if (!existsSync(path)) continue;
  // Use an isolated Node process to parse dotenv, with existing values authoritative.
  const parsed = spawnSync(process.execPath, [`--env-file=${path}`, "-e", "process.stdout.write(JSON.stringify(process.env))"], { env, encoding: "utf8" });
  if (parsed.status !== 0) throw new Error(`Environment parsing failed for ${path}`);
  const values = JSON.parse(parsed.stdout);
  for (const [key, value] of Object.entries(values)) if (!(key in env)) env[key] = value;
}
const result = spawnSync(command, args, { env, stdio: "inherit" });
if (result.error) { console.error(result.error.message); process.exit(1); }
process.exit(result.status ?? 1);
