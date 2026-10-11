import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { deriveLane, envNamesInExample, loadModel, mcpServers } from "../scripts/triage.mjs";

const files = new Set(["scripts/doctor.sh"]);
const envNames = new Set(["PERPLEXITY_API_KEY"]);

test("a file that exists is ready", () => {
  assert.deepEqual(deriveLane({ kind: "file", path: "scripts/doctor.sh" }, { files, envNames }), {
    state: "ready",
  });
});

test("a missing file is blocked", () => {
  const state = deriveLane({ kind: "file", path: "scripts/missing.sh" }, { files, envNames });
  assert.equal(state.state, "blocked");
});

test("a named secret stays operator until a person sets it", () => {
  assert.deepEqual(deriveLane({ kind: "env-name", name: "PERPLEXITY_API_KEY" }, { files, envNames }), {
    state: "operator",
  });
});

test("an unnamed secret is blocked", () => {
  assert.equal(deriveLane({ kind: "env-name", name: "OTHER_KEY" }, { files, envNames }).state, "blocked");
});

test("operator evidence cannot become ready from the repo", () => {
  assert.deepEqual(deriveLane({ kind: "operator" }, { files, envNames }), { state: "operator" });
});

test("env example parser keeps names and ignores comments", () => {
  const names = envNamesInExample("# note\nPERPLEXITY_API_KEY=\nexport FIRECRAWL_API_KEY=\n");
  assert.deepEqual([...names], ["PERPLEXITY_API_KEY", "FIRECRAWL_API_KEY"]);
});

test("the browser example is the stdio slice of the connector model", () => {
  const example = JSON.parse(readFileSync(new URL("../config/browser/mcp.example.json", import.meta.url), "utf8"));
  const generated = mcpServers(loadModel(new URL("..", import.meta.url).pathname).doc);
  for (const [id, spec] of Object.entries(example.mcpServers)) {
    assert.deepEqual(generated.mcpServers[id], spec);
  }
});

test("mcp output names the perplexity header and does not embed a key", () => {
  const text = JSON.stringify(
    mcpServers({
      connectors: [
        {
          id: "perplexity",
          kind: "remote-http",
          url: "https://api.perplexity.ai/mcp",
          auth: { type: "bearer", env: "PERPLEXITY_API_KEY" },
        },
        {
          id: "xai-docs",
          kind: "remote-http",
          url: "https://docs.x.ai/api/mcp",
          auth: { type: "none" },
        },
      ],
    }),
  );
  assert.match(text, /\$\{env:PERPLEXITY_API_KEY\}/);
  assert.doesNotMatch(text, /pplx-/);
});
