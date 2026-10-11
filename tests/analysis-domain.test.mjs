import assert from "node:assert/strict";
import test from "node:test";
import { adviseStage, analyzeText } from "../services/analysis/analyze.mjs";
import { startServer } from "../services/analysis/server.mjs";

test("monitor outranks triage and build", () => {
  const advice = adviseStage({
    incident: true,
    dirty: true,
    secretRisk: true,
    cleanDefault: true,
  });
  assert.deepEqual(advice, { stage: "monitor", reason: "incident" });
});

test("failing checks triage a clean tree", () => {
  assert.equal(adviseStage({ checksRed: true }).stage, "triage");
});

test("docs-only build requires a dirty tree", () => {
  assert.equal(adviseStage({ docsOnly: true }).stage, null);
  assert.equal(adviseStage({ dirty: true, docsOnly: true }).stage, "build");
});

test("clean default branch is build", () => {
  assert.deepEqual(adviseStage({ cleanDefault: true }), {
    stage: "build",
    reason: "cleanDefault",
  });
});

test("unknown signals are ignored", () => {
  assert.equal(adviseStage({ madeUp: true }).stage, null);
});

test("comment markers and missing scripts become findings", () => {
  const report = analyzeText("TODO ship\nscripts/missing-hook.sh\nscripts/doctor.sh\n", {
    exists: (rel) => rel === "scripts/doctor.sh",
  });
  assert.deepEqual(
    report.findings.map((finding) => [finding.rule, finding.severity, finding.line ?? finding.path]),
    [
      ["hack-marker", "note", 1],
      ["script-ref", "critical", "scripts/missing-hook.sh"],
    ],
  );
});

test("http domain, analyze, and unknown route", async () => {
  const server = await startServer(0);
  const address = server.address();
  assert.equal(typeof address, "object");
  const base = `http://127.0.0.1:${address.port}`;
  try {
    const health = await fetch(`${base}/health`);
    assert.equal((await health.json()).ok, true);
    const domain = await fetch(`${base}/v1/domain`);
    const body = await domain.json();
    assert.deepEqual(body.stages, ["monitor", "triage", "build"]);
    const analyzed = await fetch(`${base}/v1/analyze`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ text: "eslint-disable-next-line no-eval" }),
    });
    const findings = (await analyzed.json()).findings;
    assert.equal(findings[0].rule, "escape-hatch");
    const missing = await fetch(`${base}/v1/nope`);
    assert.equal(missing.status, 404);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
  }
});
