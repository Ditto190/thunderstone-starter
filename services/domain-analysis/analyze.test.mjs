import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { analyzeWorkspace, selectStage } from "./analyze.mjs";
import { dispatch } from "./dispatch.mjs";
import { loadDomain, repoRootFromHere } from "./load.mjs";

const root = repoRootFromHere(fileURLToPath(new URL(".", import.meta.url)));

test("monitor outranks triage and build", () => {
  const { stages } = loadDomain(root);
  const picked = selectStage(stages, {
    ciFailed: true,
    dirty: true,
    riskyPaths: true,
    docsOnly: true,
  });
  assert.equal(picked.stage, "Monitor");
});

test("sensitive paths triage ahead of a dirty build", () => {
  const { stages } = loadDomain(root);
  const picked = selectStage(stages, { dirty: true, riskyPaths: true });
  assert.equal(picked.stage, "Triage");
});

test("docs-only dirty tree is build", () => {
  const { stages } = loadDomain(root);
  const picked = selectStage(stages, { dirty: true, docsOnly: true });
  assert.equal(picked.stage, "Build");
});

test("no signals leave the stage empty", () => {
  const { stages } = loadDomain(root);
  const picked = selectStage(stages, {});
  assert.equal(picked.stage, null);
});

test("unknown signal is rejected", () => {
  assert.throws(() => analyzeWorkspace(root, { notASignal: true }), /unknown signal/);
});

test("workspace docs resolve and roster matches AGENTS.md", () => {
  const report = analyzeWorkspace(root);
  assert.equal(report.clan, "thunderstone");
  assert.equal(report.findings.some((item) => item.kind === "docs-drift"), false);
  assert.equal(report.roles.length, 5);
});

test("dispatch serves domain and analyze", async () => {
  const domain = dispatch({ method: "GET", pathname: "/v1/domain" });
  assert.equal(domain.status, 200);
  assert.ok(domain.body.rules.some((rule) => rule.stage === "Triage"));
  const analyzed = dispatch({
    method: "POST",
    pathname: "/api/v1/analyze",
    body: { signals: { cleanDefaultBranch: true } },
  });
  assert.equal(analyzed.body.stage, "Build");
  const missing = dispatch({ method: "GET", pathname: "/nope" });
  assert.equal(missing.status, 404);

  const server = createServer((req, res) => {
    const url = new URL(req.url || "/", "http://127.0.0.1");
    const result = dispatch({ method: req.method || "GET", pathname: url.pathname });
    res.writeHead(result.status, { "content-type": "application/json" });
    res.end(JSON.stringify(result.body));
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  const health = await fetch(`http://127.0.0.1:${address.port}/health`);
  const payload = await health.json();
  server.close();
  assert.equal(payload.ok, true);
});
