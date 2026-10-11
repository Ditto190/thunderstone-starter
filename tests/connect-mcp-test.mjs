import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const connect = join(root, "scripts/connect-mcp.mjs");
const envRun = join(root, "scripts/env-run.mjs");
const example = JSON.parse(readFileSync(join(root, "config/mcp.example.json"), "utf8"));

function run(args, env, target) {
  return spawnSync(process.execPath, [connect, ...args], {
    cwd: root,
    env: { ...process.env, PERPLEXITY_API_KEY: "", ...env, CONNECT_MCP_TARGET: target },
    encoding: "utf8",
  });
}

test("example is the oauth shape and --print matches it", () => {
  assert.equal(example.mcpServers.perplexity.url, "https://api.perplexity.ai/mcp");
  assert.equal(example.mcpServers.perplexity.headers, undefined);
  assert.equal(example.mcpServers.firecrawl.args[1], "--only");
  assert.equal(example.mcpServers.firecrawl.args[2], "FIRECRAWL_API_KEY");
  const printed = spawnSync(process.execPath, [connect, "--print"], { cwd: root, encoding: "utf8" });
  assert.equal(printed.status, 0);
  assert.deepEqual(JSON.parse(printed.stdout).mcpServers.perplexity, example.mcpServers.perplexity);
  assert.equal(printed.stdout.includes("Bearer"), false);
});

test("merge keeps operator servers and is idempotent", () => {
  const dir = mkdtempSync(join(tmpdir(), "connect-mcp-"));
  const target = join(dir, "mcp.json");
  writeFileSync(target, JSON.stringify({ mcpServers: { rustwright: { command: "rustwright-mcp" } } }));
  const first = run([], { PERPLEXITY_API_KEY: "" }, target);
  const second = run([], { PERPLEXITY_API_KEY: "" }, target);
  const body = JSON.parse(readFileSync(target, "utf8"));
  assert.equal(first.status, 0);
  assert.match(first.stdout, /^wrote perplexity=oauth\n$/);
  assert.match(second.stdout, /^unchanged perplexity=oauth\n$/);
  assert.equal(body.mcpServers.rustwright.command, "rustwright-mcp");
  assert.equal(body.mcpServers.perplexity.headers, undefined);
  rmSync(dir, { recursive: true });
});

test("a set key writes a bearer header only in the target, then oauth clears it", () => {
  const dir = mkdtempSync(join(tmpdir(), "connect-mcp-"));
  const target = join(dir, "mcp.json");
  const key = `pplx-${"a".repeat(24)}`;
  const wrote = run([], { PERPLEXITY_API_KEY: key }, target);
  const withKey = JSON.parse(readFileSync(target, "utf8"));
  assert.equal(wrote.status, 0);
  assert.equal(wrote.stdout.includes(key), false);
  assert.equal(withKey.mcpServers.perplexity.headers.Authorization, `Bearer ${key}`);
  const cleared = run([], { PERPLEXITY_API_KEY: "" }, target);
  const withoutKey = JSON.parse(readFileSync(target, "utf8"));
  assert.match(cleared.stdout, /^wrote perplexity=oauth\n$/);
  assert.equal(withoutKey.mcpServers.perplexity.headers, undefined);
  rmSync(dir, { recursive: true });
});

test("symlink and invalid json are refused", () => {
  const dir = mkdtempSync(join(tmpdir(), "connect-mcp-"));
  const target = join(dir, "mcp.json");
  const other = join(dir, "other.json");
  writeFileSync(other, "{}");
  symlinkSync(other, target);
  const linked = run([], {}, target);
  assert.equal(linked.status, 1);
  assert.match(linked.stderr, /symlink/);
  rmSync(target);
  writeFileSync(target, "{");
  const broken = run([], {}, target);
  assert.equal(broken.status, 1);
  assert.equal(readFileSync(target, "utf8"), "{");
  rmSync(dir, { recursive: true });
});

test("env-run --only loads the named key and not its sibling", () => {
  const dir = mkdtempSync(join(tmpdir(), "env-run-"));
  writeFileSync(join(dir, ".env.local"), "FIRECRAWL_API_KEY=fc-local\nPERPLEXITY_API_KEY=hidden-local\n");
  const result = spawnSync(
    process.execPath,
    [envRun, "--only", "FIRECRAWL_API_KEY", process.execPath, "-e", "process.stdout.write(JSON.stringify({fire:process.env.FIRECRAWL_API_KEY,perp:process.env.PERPLEXITY_API_KEY??null}))"],
    { cwd: dir, env: { PATH: process.env.PATH }, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { fire: "fc-local", perp: null });
  rmSync(dir, { recursive: true });
});
