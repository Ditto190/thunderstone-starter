// Render config/mcp/servers.json into per-surface MCP client configs.
//   Grok Build / Grok Bot -> .grok/config.toml   (project scope)
//   Cursor                -> .cursor/mcp.json    (project scope)
// Both outputs are generated, gitignored and contain names only: secrets are read at run
// time through scripts/env-run.mjs. This does not configure Perplexity Computer or Comet.
//
// Usage: node scripts/env-run.mjs node scripts/mcp-sync.mjs [--surface grok|cursor|all]
//          [--profile dev|vm] [--check] [--force] [--out-dir <dir>] [--print-profile]
import { createHash } from "node:crypto";
import { accessSync, constants, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const PROFILES = ["dev", "vm"];
const SURFACES = ["grok", "cursor"];

function parseArgs(argv) {
  const opts = { surface: "all", profile: "", check: false, force: false, outDir: ROOT };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--check") opts.check = true;
    else if (a === "--force") opts.force = true;
    else if (a === "--print-profile") opts.printProfile = true;
    else if (a === "--surface") opts.surface = argv[++i] ?? "";
    else if (a === "--profile") opts.profile = argv[++i] ?? "";
    else if (a === "--out-dir") opts.outDir = resolve(argv[++i] ?? "");
    else throw new Error(`Unknown argument: ${a}`);
  }
  if (opts.surface !== "all" && !SURFACES.includes(opts.surface)) throw new Error(`--surface must be one of: all, ${SURFACES.join(", ")}`);
  return opts;
}

function detectProfile(env) {
  const wanted = env.THUNDERSTONE_PROFILE;
  if (wanted) {
    if (!PROFILES.includes(wanted)) throw new Error(`THUNDERSTONE_PROFILE must be one of: ${PROFILES.join(", ")}`);
    return wanted;
  }
  // The Grok Bot VM is an Xfce desktop; anything else defaults to the lean dev profile.
  return /xfce/i.test(env.XDG_CURRENT_DESKTOP ?? "") ? "vm" : "dev";
}

const list = (value) => (value ?? "").split(",").map((s) => s.trim()).filter(Boolean);

function onPath(bin, env) {
  const dirs = [...(env.PATH ?? "").split(delimiter), join(homedir(), ".local/bin")];
  return dirs.some((dir) => {
    try { accessSync(join(dir, bin), constants.X_OK); return true; } catch { return false; }
  });
}

export function loadManifest(file = join(ROOT, "config/mcp/servers.json")) {
  const manifest = JSON.parse(readFileSync(file, "utf8"));
  const servers = manifest.servers ?? {};
  for (const [name, s] of Object.entries(servers)) {
    if (!/^[a-z0-9][a-z0-9-]*$/.test(name)) throw new Error(`Invalid server name: ${name}`);
    const kinds = ["command", "script", "url"].filter((k) => s[k]);
    if (kinds.length !== 1) throw new Error(`${name}: set exactly one of command, script, url`);
    if (!Array.isArray(s.profiles) || !s.profiles.every((p) => PROFILES.includes(p))) throw new Error(`${name}: invalid profiles`);
    if (typeof s.default !== "boolean") throw new Error(`${name}: default must be boolean`);
    if (s.args && !(Array.isArray(s.args) && s.args.every((a) => typeof a === "string"))) throw new Error(`${name}: args must be strings`);
    if (s.url && !/^https:\/\//.test(s.url)) throw new Error(`${name}: remote URLs must be https`);
    for (const key of s.requiresEnv ?? []) if (!/^[A-Z][A-Z0-9_]*$/.test(key)) throw new Error(`${name}: bad env name ${key}`);
  }
  return servers;
}

// Decide which servers are active for a profile and explain every skip.
export function select(servers, profile, env) {
  const enable = new Set(list(env.MCP_ENABLE));
  const disable = new Set(list(env.MCP_DISABLE));
  const active = {};
  const skipped = [];
  const warnings = [];
  for (const [name, s] of Object.entries(servers)) {
    if (!s.profiles.includes(profile)) { skipped.push([name, `not in profile ${profile}`]); continue; }
    if (disable.has(name)) { skipped.push([name, "MCP_DISABLE"]); continue; }
    if (!s.default && !enable.has(name)) { skipped.push([name, "off by default (add to MCP_ENABLE)"]); continue; }
    const missingEnv = (s.requiresEnv ?? []).filter((k) => !env[k]);
    if (missingEnv.length) { skipped.push([name, `missing ${missingEnv.join(", ")}`]); continue; }
    const missingBin = (s.requiresBin ?? []).filter((b) => !onPath(b, env));
    if (missingBin.length) { skipped.push([name, `not installed: ${missingBin.join(", ")}`]); continue; }
    if (s.requiresDisplay && !env.DISPLAY && !env.WAYLAND_DISPLAY) warnings.push(`${name}: no DISPLAY in this shell; it only works inside the desktop session`);
    active[name] = s;
  }
  return { active, skipped, warnings };
}

function resolveEntry(name, s, env, root) {
  if (s.url) return { url: s.url };
  const port = env.BROWSER_CDP_PORT || "9222";
  if (!/^[0-9]+$/.test(port)) throw new Error("BROWSER_CDP_PORT must be numeric");
  const fill = (a) => a.replaceAll("{BROWSER_CDP_PORT}", port);
  const command = s.script ? "bash" : s.command;
  const args = s.script ? [join(root, s.script)] : (s.args ?? []).map(fill);
  if (s.wrap === false) return { command, args };
  // env-run injects .env.local, ~/.config/thunderstone/env and /run/secrets values at launch.
  return { command: "node", args: [join(root, "scripts/env-run.mjs"), command, ...args] };
}

export function renderCursor(entries) {
  return `${JSON.stringify({ mcpServers: entries }, null, 2)}\n`;
}

export function renderGrok(entries, profile) {
  const lines = [
    "# Generated by scripts/mcp-sync.mjs from config/mcp/servers.json. Do not edit by hand.",
    `# Surface: Grok Build / Grok Bot. Profile: ${profile}. Re-run: bash scripts/agent-setup.sh --sync`,
    "",
  ];
  for (const [name, e] of Object.entries(entries)) {
    lines.push(`[mcp_servers.${name}]`);
    if (e.url) lines.push(`url = ${JSON.stringify(e.url)}`);
    else {
      lines.push(`command = ${JSON.stringify(e.command)}`);
      lines.push(`args = [${e.args.map((a) => JSON.stringify(a)).join(", ")}]`);
      lines.push("startup_timeout_sec = 90");
    }
    lines.push("");
  }
  return `${lines.join("\n")}\n`.replace(/\n{3,}$/, "\n");
}

const sha = (text) => createHash("sha256").update(text).digest("hex");

// Write only when the file is absent, already identical, previously generated by us, or the old
// hand-copied example. Anything else is the user's own config and is left alone.
function safeWrite(file, text, state, force) {
  const next = sha(text);
  if (existsSync(file)) {
    const current = readFileSync(file, "utf8");
    const legacy = join(ROOT, "config/browser/mcp.example.json");
    const ours = sha(current) === state[file] || (existsSync(legacy) && current === readFileSync(legacy, "utf8"));
    if (current === text) { state[file] = next; return "unchanged"; }
    if (!ours && !force) return "refused (existing file was not generated here; rerun with --force)";
  }
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text, { mode: 0o600 });
  state[file] = next;
  return "written";
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (process.platform === "win32") {
    console.error("mcp-sync supports Linux and macOS. For Windows Cursor, follow docs/agent-connectors/COMPUTER-USE.md.");
    process.exit(2);
  }
  const env = process.env;
  const profile = opts.profile || detectProfile(env);
  if (opts.printProfile) { console.log(profile); return; }
  if (!PROFILES.includes(profile)) throw new Error(`--profile must be one of: ${PROFILES.join(", ")}`);
  const servers = loadManifest();
  const { active, skipped, warnings } = select(servers, profile, env);
  const entries = Object.fromEntries(Object.entries(active).map(([n, s]) => [n, resolveEntry(n, s, env, ROOT)]));
  const surfaces = opts.surface === "all" ? SURFACES : [opts.surface];
  const outputs = {
    cursor: [join(opts.outDir, ".cursor/mcp.json"), renderCursor(entries)],
    grok: [join(opts.outDir, ".grok/config.toml"), renderGrok(entries, profile)],
  };

  console.log(`profile=${profile} surfaces=${surfaces.join(",")}`);
  console.log(`enabled: ${Object.keys(active).join(", ") || "(none)"}`);
  for (const [name, why] of skipped) console.log(`skipped: ${name} (${why})`);
  for (const w of warnings) console.log(`warning: ${w}`);

  if (opts.check) {
    JSON.parse(outputs.cursor[1]);
    if (!/^\[mcp_servers\.[a-z0-9-]+\]$/m.test(outputs.grok[1]) && Object.keys(entries).length) throw new Error("Grok render produced no server tables");
    console.log("check ok (nothing written)");
    return;
  }
  const stateFile = join(opts.outDir, ".state/mcp-sync.json");
  const state = existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, "utf8")) : {};
  for (const surface of surfaces) {
    const [file, text] = outputs[surface];
    const result = safeWrite(file, text, state, opts.force);
    console.log(`${surface}: ${result}`);
  }
  mkdirSync(dirname(stateFile), { recursive: true });
  writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(); } catch (error) { console.error(error.message); process.exit(1); }
}
