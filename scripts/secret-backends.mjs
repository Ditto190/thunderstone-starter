import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

/** @typedef {"off" | "auto" | "infisical" | "doppler" | "fixture"} SecretsBackend */

/**
 * Parse a dotenv file path into key/value pairs without mutating or printing secrets.
 * @param {string} path
 * @param {NodeJS.ProcessEnv} baseEnv
 * @returns {Record<string, string>}
 */
export function parseEnvFile(path, baseEnv) {
  const parsed = spawnSync(process.execPath, [`--env-file=${path}`, "-e", "process.stdout.write(JSON.stringify(process.env))"], {
    env: baseEnv,
    encoding: "utf8",
  });
  if (parsed.status !== 0) {
    throw new Error(`Environment parsing failed for ${path}`);
  }
  const values = JSON.parse(parsed.stdout);
  const out = {};
  for (const [key, value] of Object.entries(values)) {
    if (typeof value === "string") out[key] = value;
  }
  return out;
}

/**
 * @param {string} dotenvText
 * @param {NodeJS.ProcessEnv} baseEnv
 * @returns {Record<string, string>}
 */
function parseDotenvText(dotenvText, baseEnv) {
  const dir = mkdtempSync(resolve(tmpdir(), "thunderstone-env-"));
  const file = resolve(dir, "layer.env");
  try {
    writeFileSync(file, dotenvText, "utf8");
    return parseEnvFile(file, baseEnv);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function commandExists(name) {
  const which = spawnSync("command", ["-v", name], { encoding: "utf8", shell: true });
  return which.status === 0;
}

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {SecretsBackend}
 */
export function resolveSecretsBackend(env) {
  const raw = (env.THUNDERSTONE_SECRETS_BACKEND ?? "off").trim().toLowerCase();
  if (raw === "" || raw === "off" || raw === "false" || raw === "0") return "off";
  if (raw === "auto") return "auto";
  if (raw === "infisical" || raw === "doppler" || raw === "fixture") return raw;
  throw new Error(`Unknown THUNDERSTONE_SECRETS_BACKEND: ${raw}`);
}

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {SecretsBackend | null}
 */
function pickAutoBackend(env) {
  if (env.INFISICAL_TOKEN && commandExists("infisical")) return "infisical";
  if (env.DOPPLER_TOKEN && commandExists("doppler")) return "doppler";
  return null;
}

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {Record<string, string>}
 */
function fetchInfisical(env) {
  if (!commandExists("infisical")) {
    throw new Error("Infisical CLI not on PATH; install https://infisical.com/docs/cli/overview");
  }
  if (!env.INFISICAL_TOKEN) {
    throw new Error("INFISICAL_TOKEN is required when THUNDERSTONE_SECRETS_BACKEND=infisical");
  }
  const infisicalEnv = env.INFISICAL_ENV ?? "dev";
  const args = ["export", "--format=dotenv", `--env=${infisicalEnv}`];
  if (env.INFISICAL_PROJECT_ID) args.push(`--projectId=${env.INFISICAL_PROJECT_ID}`);
  const run = spawnSync("infisical", args, {
    env,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
  if (run.status !== 0) {
    const detail = (run.stderr || run.stdout || "infisical export failed").trim().split("\n")[0];
    throw new Error(`Infisical export failed: ${detail}`);
  }
  return parseDotenvText(run.stdout, env);
}

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {Record<string, string>}
 */
function fetchDoppler(env) {
  if (!commandExists("doppler")) {
    throw new Error("Doppler CLI not on PATH; install https://docs.doppler.com/docs/install-cli");
  }
  const args = ["secrets", "download", "--no-file", "--format", "dotenv"];
  const run = spawnSync("doppler", args, {
    env,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
  if (run.status !== 0) {
    const detail = (run.stderr || run.stdout || "doppler download failed").trim().split("\n")[0];
    throw new Error(`Doppler download failed: ${detail}`);
  }
  return parseDotenvText(run.stdout, env);
}

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {Record<string, string>}
 */
function fetchFixture(env) {
  const path = env.THUNDERSTONE_SECRETS_FIXTURE;
  if (!path || !existsSync(path)) {
    throw new Error("THUNDERSTONE_SECRETS_FIXTURE must point at a readable dotenv file for fixture backend");
  }
  return parseEnvFile(resolve(path), env);
}

/**
 * Load secrets from the configured manager. Never logs values.
 * @param {NodeJS.ProcessEnv} env
 * @returns {Record<string, string>}
 */
export function fetchManagedSecrets(env) {
  const mode = resolveSecretsBackend(env);
  if (mode === "off") return {};
  const effective = mode === "auto" ? pickAutoBackend(env) : mode;
  if (!effective) return {};
  switch (effective) {
    case "infisical":
      return fetchInfisical(env);
    case "doppler":
      return fetchDoppler(env);
    case "fixture":
      return fetchFixture(env);
    default:
      return {};
  }
}
