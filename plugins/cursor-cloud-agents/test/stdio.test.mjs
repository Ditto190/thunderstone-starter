import { test, afterEach } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";
import { startFakeApi, FAKE_KEY, AGENT_ID, RUN_ID, agentFixture, runFixture } from "./helpers/fake-api.mjs";

const SERVER = fileURLToPath(new URL("../server/index.mjs", import.meta.url));
const cleanups = [];
afterEach(async () => {
  while (cleanups.length) await cleanups.pop()();
});

async function launch(routes = {}, envOver = {}) {
  const api = await startFakeApi(routes);
  const env = { PATH: process.env.PATH, CURSOR_API_KEY: FAKE_KEY, CURSOR_API_BASE_URL: api.baseUrl, ...envOver };
  const child = spawn(process.execPath, [SERVER], { env, stdio: ["pipe", "pipe", "pipe"] });
  const stdoutLines = [];
  let stderr = "";
  const waiters = new Map();
  createInterface({ input: child.stdout }).on("line", (line) => {
    stdoutLines.push(line);
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }
    waiters.get(msg.id)?.(msg);
  });
  child.stderr.on("data", (d) => { stderr += d; });
  const exited = new Promise((resolve) => child.on("exit", (code, signal) => resolve({ code, signal })));
  cleanups.push(async () => { child.kill("SIGKILL"); await api.close(); });
  let nextId = 1;
  const rpc = (method, params, id = nextId++) =>
    new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`timeout waiting for ${method}`)), 5000);
      waiters.set(id, (m) => { clearTimeout(timer); resolve(m); });
      child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    });
  const notify = (method, params) => child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  return { api, child, rpc, notify, stdoutLines, stderr: () => stderr, exited };
}

test("legacy handshake: initialize echoes a supported version, then tools/list and ping", async () => {
  const s = await launch();
  const init = await s.rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "t", version: "0" } });
  assert.equal(init.result.protocolVersion, "2025-06-18");
  assert.ok(init.result.capabilities.tools);
  assert.equal(init.result.serverInfo.name, "cursor-cloud-agents");
  s.notify("notifications/initialized");
  const list = await s.rpc("tools/list", {});
  assert.deepEqual(list.result.tools.map((t) => t.name).sort(), ["cancel", "followup", "get_artifacts", "get_status", "launch_agent", "list_agents"]);
  assert.equal(list.result.resultType, undefined);
  assert.deepEqual((await s.rpc("ping", {})).result, {});
});

test("version negotiation: unknown or newer requested version falls back to the latest legacy version", async () => {
  const s = await launch();
  assert.equal((await s.rpc("initialize", { protocolVersion: "2099-01-01" })).result.protocolVersion, "2025-11-25");
  assert.equal((await s.rpc("initialize", { protocolVersion: "2024-11-05" })).result.protocolVersion, "2024-11-05");
  assert.equal((await s.rpc("initialize", {})).result.protocolVersion, "2025-11-25");
});

test("tools/call get_status over stdio hits the fake API and returns text plus structuredContent", async () => {
  const s = await launch({
    [`GET /v1/agents/${AGENT_ID}`]: { body: agentFixture() },
    [`GET /v1/agents/${AGENT_ID}/runs/${RUN_ID}`]: { body: runFixture({ status: "CREATING" }) },
  });
  await s.rpc("initialize", { protocolVersion: "2025-11-25" });
  const res = await s.rpc("tools/call", { name: "get_status", arguments: { agentId: AGENT_ID } });
  assert.equal(res.result.isError, false);
  assert.equal(res.result.structuredContent.run.status, "CREATING");
  assert.equal(res.result.structuredContent.nextPollSeconds, 5);
  assert.equal(JSON.parse(res.result.content[0].text).agent.id, AGENT_ID);
  assert.equal(s.api.requests[0].headers.authorization, `Bearer ${FAKE_KEY}`);
});

test("tools/call: guard errors come back as isError results, not protocol errors; no API call made", async () => {
  const s = await launch();
  const res = await s.rpc("tools/call", { name: "launch_agent", arguments: { prompt: "x", repoUrl: "https://github.com/example-org/example-repo" } });
  assert.equal(res.error, undefined);
  assert.equal(res.result.isError, true);
  assert.equal(res.result.structuredContent.error.code, "confirmation_required");
  assert.equal(s.api.requests.length, 0);
});

test("tools/call: launch cap enforced across calls within one server process", async () => {
  const s = await launch({ "POST /v1/agents": { status: 201, body: { agent: agentFixture(), run: runFixture({ status: "CREATING" }) } } }, { CURSOR_MAX_LAUNCHES_PER_SESSION: "1" });
  const args = { prompt: "x", repoUrl: "https://github.com/example-org/example-repo", confirm: true };
  assert.equal((await s.rpc("tools/call", { name: "launch_agent", arguments: args })).result.isError, false);
  const second = await s.rpc("tools/call", { name: "launch_agent", arguments: args });
  assert.equal(second.result.structuredContent.error.code, "launch_cap_reached");
  assert.equal(s.api.requests.length, 1);
});

test("protocol errors: unknown method, unknown tool, bad params, invalid JSON", async () => {
  const s = await launch();
  assert.equal((await s.rpc("nope/method", {})).error.code, -32601);
  assert.equal((await s.rpc("tools/call", { name: "delete_agent", arguments: {} })).error.code, -32602);
  assert.equal((await s.rpc("tools/call", {})).error.code, -32602);
  const parseErr = new Promise((resolve) => {
    const onData = (line) => { if (line.includes("-32700")) resolve(JSON.parse(line)); };
    const check = setInterval(() => s.stdoutLines.filter(onData), 10);
    setTimeout(() => clearInterval(check), 3000);
  });
  s.child.stdin.write("{not json\n");
  const msg = await parseErr;
  assert.equal(msg.error.code, -32700);
  assert.equal(msg.id, null);
  assert.deepEqual((await s.rpc("ping", {})).result, {});
});

test("stateless 2026-07-28 era: server/discover, per-request _meta, resultType, unsupported version error", async () => {
  const s = await launch();
  const meta = { "io.modelcontextprotocol/protocolVersion": "2026-07-28", "io.modelcontextprotocol/clientInfo": { name: "t", version: "0" }, "io.modelcontextprotocol/clientCapabilities": {} };
  const disc = await s.rpc("server/discover", { _meta: meta });
  assert.equal(disc.result.resultType, "complete");
  assert.ok(disc.result.supportedVersions.includes("2026-07-28"));
  assert.ok(disc.result.supportedVersions.includes("2025-11-25"));
  assert.equal(disc.result._meta["io.modelcontextprotocol/serverInfo"].name, "cursor-cloud-agents");
  const list = await s.rpc("tools/list", { _meta: meta });
  assert.equal(list.result.resultType, "complete");
  assert.equal(list.result.tools.length, 6);
  const bad = await s.rpc("tools/list", { _meta: { ...meta, "io.modelcontextprotocol/protocolVersion": "1900-01-01" } });
  assert.equal(bad.error.code, -32022);
  assert.deepEqual(bad.error.data.requested, "1900-01-01");
  assert.ok(bad.error.data.supported.includes("2026-07-28"));
});

test("stdout is protocol-only and neither stdout nor stderr ever contains the key", async () => {
  const s = await launch({ "GET /v1/agents": { status: 400, body: { code: "bad_request", message: `echo ${FAKE_KEY}` } } }, { CURSOR_MCP_DEBUG: "1" });
  await s.rpc("initialize", { protocolVersion: "2025-11-25" });
  await s.rpc("tools/call", { name: "list_agents", arguments: {} });
  await s.rpc("tools/list", {});
  assert.ok(s.stdoutLines.length >= 3);
  for (const line of s.stdoutLines) {
    const msg = JSON.parse(line); // throws if anything other than JSON reached stdout
    assert.equal(msg.jsonrpc, "2.0");
    assert.ok(!line.includes(FAKE_KEY));
    assert.ok(!line.includes("\n"));
  }
  assert.ok(!s.stderr().includes(FAKE_KEY));
});

test("closing stdin exits cleanly (graceful shutdown), after in-flight work", async () => {
  const s = await launch({ "GET /v1/agents": { delayMs: 200, body: { items: [] } } });
  const pending = s.rpc("tools/call", { name: "list_agents", arguments: {} });
  s.child.stdin.end();
  const res = await pending;
  assert.equal(res.result.isError, false);
  const { code } = await s.exited;
  assert.equal(code, 0);
});

test("server starts and lists tools without a key; calls then fail with missing_api_key", async () => {
  const s = await launch({}, { CURSOR_API_KEY: "" });
  assert.equal((await s.rpc("tools/list", {})).result.tools.length, 6);
  const res = await s.rpc("tools/call", { name: "list_agents", arguments: {} });
  assert.equal(res.result.structuredContent.error.code, "missing_api_key");
  assert.equal(s.api.requests.length, 0);
});
