import { existsSync, lstatSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const examplePath = resolve(root, "config/mcp.example.json");
const perplexityUrl = "https://api.perplexity.ai/mcp";
const targetPath = process.env.CONNECT_MCP_TARGET
  ? resolve(process.env.CONNECT_MCP_TARGET)
  : resolve(root, ".cursor/mcp.json");

function canonical(value) {
  return `${JSON.stringify(sortKeys(value), null, 2)}\n`;
}

function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, sortKeys(value[key])]));
  }
  return value;
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    throw new Error(`connect-mcp: refused; ${path} is not valid JSON`);
  }
}

function assertExample(example) {
  const servers = example?.mcpServers;
  if (!servers || typeof servers !== "object" || Array.isArray(servers)) {
    throw new Error("connect-mcp: config/mcp.example.json has no mcpServers object");
  }
  const perplexity = servers.perplexity;
  if (!perplexity || perplexity.url !== perplexityUrl || perplexity.headers || perplexity.command) {
    throw new Error("connect-mcp: perplexity must be the hosted URL with no command and no headers");
  }
  const names = Object.entries(servers)
    .filter(([, server]) => typeof server?.url === "string" && server.url.includes("perplexity.ai"))
    .map(([name]) => name);
  if (names.length !== 1 || names[0] !== "perplexity") {
    throw new Error("connect-mcp: exactly one Perplexity server, named perplexity, is allowed");
  }
  for (const [name, server] of Object.entries(servers)) {
    if (typeof server?.url === "string" && server.url.includes("/rest/computer/mcp")) {
      throw new Error(`connect-mcp: server ${name} is the Computer MCP and is not part of this map`);
    }
  }
}

function readExisting() {
  if (!existsSync(targetPath)) return { mcpServers: {} };
  const stat = lstatSync(targetPath);
  if (stat.isSymbolicLink()) throw new Error("connect-mcp: refused; target is a symlink");
  const existing = readJson(targetPath);
  if (!existing || typeof existing !== "object" || Array.isArray(existing)) {
    throw new Error("connect-mcp: refused; target is not a JSON object");
  }
  if (existing.mcpServers !== undefined && (typeof existing.mcpServers !== "object" || Array.isArray(existing.mcpServers))) {
    throw new Error("connect-mcp: refused; target mcpServers is not an object");
  }
  return existing;
}

function render(example, existing, apiKey) {
  const servers = { ...(existing.mcpServers ?? {}), ...example.mcpServers };
  const perplexity = { ...example.mcpServers.perplexity };
  if (apiKey) perplexity.headers = { Authorization: `Bearer ${apiKey}` };
  else delete perplexity.headers;
  servers.perplexity = perplexity;
  return { ...existing, mcpServers: servers };
}

function writeIfChanged(text) {
  mkdirSync(dirname(targetPath), { recursive: true });
  if (existsSync(targetPath) && readFileSync(targetPath, "utf8") === text) return "unchanged";
  const temporary = join(tmpdir(), `.connect-mcp-${process.pid}.json`);
  writeFileSync(temporary, text);
  try {
    renameSync(temporary, targetPath);
  } catch {
    writeFileSync(targetPath, text);
    rmSync(temporary, { force: true });
  }
  return "wrote";
}

function main() {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args[0] && args[0] !== "--print")) {
    throw new Error("Usage: node scripts/connect-mcp.mjs [--print]");
  }
  const example = readJson(examplePath);
  assertExample(example);
  if (args[0] === "--print") {
    process.stdout.write(canonical(render(example, { mcpServers: {} }, "")));
    return;
  }
  const apiKey = process.env.PERPLEXITY_API_KEY ?? "";
  if (apiKey && !/^[^\s]{8,}$/.test(apiKey)) {
    throw new Error("connect-mcp: refused; PERPLEXITY_API_KEY is set but does not look like a token");
  }
  const status = writeIfChanged(canonical(render(example, readExisting(), apiKey)));
  const mode = apiKey ? "bearer" : "oauth";
  process.stdout.write(`${status} perplexity=${mode}\n`);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : "connect-mcp: refused");
  process.exit(1);
}
