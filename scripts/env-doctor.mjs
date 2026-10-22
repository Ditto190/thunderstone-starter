import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { fetchManagedSecrets, parseEnvFile, resolveSecretsBackend } from "./secret-backends.mjs";

const registryPath = resolve("config/env.registry.json");
const surface = (process.env.THUNDERSTONE_SURFACE ?? "vm_worker").trim();

function commandExists(name) {
  return spawnSync("command", ["-v", name], { encoding: "utf8", shell: true }).status === 0;
}

function loadRegistry() {
  if (!existsSync(registryPath)) throw new Error("Missing config/env.registry.json");
  return JSON.parse(readFileSync(registryPath, "utf8"));
}

function fileLayerPaths() {
  return [
    "/run/secrets/thunderstone.env",
    resolve(homedir(), ".config/thunderstone/env"),
    resolve(".env.local"),
    resolve(".env.defaults"),
  ];
}

function mergedEnvForCheck() {
  const env = { ...process.env };
  const managed = fetchManagedSecrets(env);
  for (const [key, value] of Object.entries(managed)) {
    if (!(key in env)) env[key] = value;
  }
  for (const path of fileLayerPaths()) {
    if (!existsSync(path)) continue;
    const values = parseEnvFile(path, env);
    for (const [key, value] of Object.entries(values)) {
      if (!(key in env)) env[key] = value;
    }
  }
  return env;
}

function isSet(env, key) {
  const v = env[key];
  return v !== undefined && v !== "";
}

function optionalKey(name) {
  const optional = new Set([
    "CURSOR_API_KEY",
    "CONTEXT7_API_KEY",
    "RCLONE_CONFIG",
    "DRIVE_EXPORT_ROOT",
    "ALLOW_LOCAL_COMMITS",
    "THUNDERSTONE_SECRETS_BACKEND",
    "INFISICAL_TOKEN",
    "INFISICAL_PROJECT_ID",
    "INFISICAL_ENV",
    "DOPPLER_TOKEN",
    "DOPPLER_PROJECT",
    "DOPPLER_CONFIG",
    "CURSOR_WORKER_AUTOSTART",
    "CURSOR_WORKER_COMPUTER_USE",
  ]);
  return optional.has(name);
}

function main() {
  const registry = loadRegistry();
  const backend = resolveSecretsBackend(process.env);
  let managedError = null;
  let env = { ...process.env };
  try {
    env = mergedEnvForCheck();
  } catch (err) {
    managedError = err instanceof Error ? err.message : String(err);
  }

  const presentLayers = fileLayerPaths().filter((p) => existsSync(p));
  console.log(`surface=${surface}`);
  console.log(`secrets_backend=${backend}`);
  console.log(`file_layers=${presentLayers.length ? presentLayers.join(",") : "(none)"}`);
  if (managedError) console.log(`managed_secrets_error=${managedError}`);

  for (const mgr of registry.secret_managers ?? []) {
    console.log(`cli_${mgr.id}=${commandExists(mgr.cli) ? "ok" : "missing"}`);
  }

  let warn = managedError ? 1 : 0;
  for (const entry of registry.keys ?? []) {
    if (!Array.isArray(entry.surfaces) || !entry.surfaces.includes(surface)) continue;
    const status = isSet(env, entry.name) ? "set" : "missing";
    const tag = entry.secret ? "secret" : "config";
    console.log(`${status} ${tag} ${entry.name}`);
    if (status === "missing" && !optionalKey(entry.name)) warn = 1;
  }

  process.exit(warn);
}

main();
