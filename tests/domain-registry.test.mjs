import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const registry = JSON.parse(
  readFileSync(join(root, "config/domains/registry.json"), "utf8"),
);

assert.equal(registry.schema_version, 1);
assert.ok(registry.entries.some((e) => e.id === "pr_orchestration"));
for (const stage of registry.stages) {
  assert.ok(Array.isArray(registry.transitions[stage]));
}
console.log("domain-registry.test.mjs passed.");
