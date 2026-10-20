import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (p) => readFileSync(join(root, p), "utf8");

test("layout matches Cursor Agent Plugins: root manifests and a skill directory", () => {
  assert.ok(statSync(join(root, "plugin.json")).isFile());
  assert.ok(statSync(join(root, "mcp.json")).isFile());
  assert.ok(statSync(join(root, "skills", "cursor-cloud-agents", "SKILL.md")).isFile());
  assert.throws(() => statSync(join(root, ".cursor-plugin", "plugin.json")));
});

test("plugin.json follows the Agent Plugins manifest schema (required and allowed fields only)", () => {
  const m = JSON.parse(read("plugin.json"));
  const allowed = new Set(["$schema", "name", "version", "description", "author", "homepage", "repository", "license", "keywords", "extensions"]);
  assert.equal(m.$schema, "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json");
  assert.match(m.name, /^(?!.*(?:--|\.\.))[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$/);
  assert.ok(m.name.length <= 64);
  for (const k of Object.keys(m)) assert.ok(allowed.has(k), `unexpected field ${k}`);
});

test("mcp.json: one stdio server, key only as a placeholder, no literal secrets", () => {
  const raw = read("mcp.json");
  const m = JSON.parse(raw);
  assert.equal(m.$schema, "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json");
  const s = m.mcpServers["cursor-cloud-agents"];
  assert.equal(s.type, "stdio");
  assert.equal(s.command, "node");
  assert.deepEqual(s.args, ["${CURSOR_PLUGIN_ROOT}/server/index.mjs"]);
  assert.equal(s.env.CURSOR_API_KEY, "${CURSOR_API_KEY}");
  assert.deepEqual(Object.keys(s.env), ["CURSOR_API_KEY"]);
  assert.ok(!/crsr_|Bearer|Basic /.test(raw));
});

test("skill has valid frontmatter and mentions the guards", () => {
  const s = read("skills/cursor-cloud-agents/SKILL.md");
  const fm = /^---\nname: ([a-z0-9-]+)\ndescription: ([\s\S]+?)\n---\n/.exec(s);
  assert.ok(fm, "frontmatter");
  assert.equal(fm[1], "cursor-cloud-agents");
  for (const word of ["confirm", "nextPollSeconds", "agent_busy"]) assert.ok(s.includes(word), word);
});

test("no delete/archive/unarchive REST call and no timers exist in server source", () => {
  const dir = join(root, "server");
  for (const f of readdirSync(dir)) {
    const src = readFileSync(join(dir, f), "utf8");
    assert.ok(!/["'`]DELETE["'`]/.test(src), `${f} issues DELETE`);
    assert.ok(!/\/archive|\/unarchive/.test(src), `${f} touches archive endpoints`);
    assert.ok(!/setInterval|setTimeout/.test(src), `${f} schedules work`);
  }
});

test("zero dependencies: server imports only node: builtins and sibling files", () => {
  const dir = join(root, "server");
  for (const f of readdirSync(dir)) {
    const src = readFileSync(join(dir, f), "utf8");
    for (const m of src.matchAll(/^import .* from "([^"]+)";?$/gm)) assert.ok(m[1].startsWith("node:") || m[1].startsWith("./"), `${f}: ${m[1]}`);
  }
  assert.ok(statSync(join(root, "server", "index.mjs")).isFile());
});
