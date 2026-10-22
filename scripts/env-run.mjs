import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { fetchManagedSecrets, parseEnvFile } from "./secret-backends.mjs";

const [command, ...args] = process.argv.slice(2);
if (!command) throw new Error("Usage: node scripts/env-run.mjs <command> [args...]");
const env = { ...process.env };
const managed = fetchManagedSecrets(env);
for (const [key, value] of Object.entries(managed)) {
  if (!(key in env)) env[key] = value;
}
for (const path of [
  "/run/secrets/thunderstone.env",
  resolve(homedir(), ".config/thunderstone/env"),
  resolve(".env.local"),
  resolve(".env.defaults"),
]) {
  if (!existsSync(path)) continue;
  const values = parseEnvFile(path, env);
  for (const [key, value] of Object.entries(values)) if (!(key in env)) env[key] = value;
}
const result = spawnSync(command, args, { env, stdio: "inherit" });
if (result.error) { console.error(result.error.message); process.exit(1); }
process.exit(result.status ?? 1);
