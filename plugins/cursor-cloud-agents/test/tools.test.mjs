import { test, afterEach } from "node:test";
import assert from "node:assert/strict";
import { createToolbox, TOOL_DEFINITIONS, nextPollSeconds, resolveLaunchCap, parseAllowedRepoPrefixes } from "../server/tools.mjs";
import { resolveBaseUrl, resolveApiKey, parseErrorBody } from "../server/client.mjs";
import { redact } from "../server/redact.mjs";
import { startFakeApi, FAKE_KEY, AGENT_ID, RUN_ID, RUN_ID_2, agentFixture, runFixture } from "./helpers/fake-api.mjs";

const open = [];
afterEach(async () => {
  while (open.length) await open.pop().close();
});

async function setup(routes = {}, envOver = {}) {
  const api = await startFakeApi(routes);
  open.push(api);
  const env = { CURSOR_API_KEY: FAKE_KEY, CURSOR_API_BASE_URL: api.baseUrl, ...envOver };
  return { api, env, box: createToolbox({ env }) };
}

const LAUNCH = { prompt: "Add a README", repoUrl: "https://github.com/example-org/example-repo", confirm: true };
const launchOk = () => ({ status: 201, body: { agent: agentFixture({ status: "ACTIVE" }), run: runFixture({ status: "CREATING" }) } });

test("tool list: exactly the six tools, no delete or archive tool", () => {
  assert.deepEqual(TOOL_DEFINITIONS.map((t) => t.name), ["launch_agent", "get_status", "followup", "list_agents", "cancel", "get_artifacts"]);
  for (const t of TOOL_DEFINITIONS) {
    assert.equal(t.inputSchema.type, "object");
    assert.ok(!/delete|archive/i.test(t.name));
  }
});

test("launch_agent: POST /v1/agents, Bearer auth, safe defaults, immediate {agentId, runId}", async () => {
  const { api, box } = await setup({ "POST /v1/agents": launchOk });
  const out = await box.call("launch_agent", { ...LAUNCH, startingRef: "main", model: "composer-2", name: "Docs", mode: "plan" });
  assert.equal(out.isError, false);
  assert.equal(out.data.agentId, AGENT_ID);
  assert.equal(out.data.runId, RUN_ID);
  assert.equal(out.data.autoCreatePR, false);
  assert.equal(out.data.launchesRemaining, 2);
  assert.ok(out.data.nextPollSeconds > 0);
  const req = api.requests[0];
  assert.equal(req.method, "POST");
  assert.equal(req.path, "/v1/agents");
  assert.equal(req.headers.authorization, `Bearer ${FAKE_KEY}`);
  assert.deepEqual(req.body, {
    prompt: { text: "Add a README" },
    repos: [{ url: "https://github.com/example-org/example-repo", startingRef: "main" }],
    autoCreatePR: false,
    workOnCurrentBranch: false,
    model: { id: "composer-2" },
    name: "Docs",
    mode: "plan",
  });
});

test("launch_agent: autoCreatePR true only when asked, prUrl passes through", async () => {
  const { api, box } = await setup({ "POST /v1/agents": launchOk });
  await box.call("launch_agent", { ...LAUNCH, autoCreatePR: true, prUrl: "https://github.com/example-org/example-repo/pull/1" });
  assert.equal(api.requests[0].body.autoCreatePR, true);
  assert.equal(api.requests[0].body.repos[0].prUrl, "https://github.com/example-org/example-repo/pull/1");
});

test("launch_agent: confirm guard (missing, false, string) sends nothing", async () => {
  const { api, box } = await setup({ "POST /v1/agents": launchOk });
  for (const confirm of [undefined, false, "true", 1]) {
    const args = { ...LAUNCH };
    if (confirm === undefined) delete args.confirm;
    else args.confirm = confirm;
    const out = await box.call("launch_agent", args);
    assert.equal(out.isError, true);
    assert.equal(out.data.error.code, "confirmation_required");
  }
  assert.equal(api.requests.length, 0);
  assert.equal(box.state().launchesUsed, 0);
});

test("launch_agent: input validation", async () => {
  const { api, box } = await setup({ "POST /v1/agents": launchOk });
  const bad = [
    { ...LAUNCH, prompt: "  " },
    { ...LAUNCH, repoUrl: undefined },
    { ...LAUNCH, repoUrl: "ftp://example.org/x" },
    { ...LAUNCH, repoUrl: "https://user:pw@example.org/x" },
    { ...LAUNCH, mode: "yolo" },
    { ...LAUNCH, name: "n".repeat(101) },
    { ...LAUNCH, autoCreatePR: "yes" },
  ];
  for (const args of bad) {
    const out = await box.call("launch_agent", args);
    assert.equal(out.isError, true, JSON.stringify(args));
    assert.equal(out.data.error.code, "invalid_input");
  }
  assert.equal(api.requests.length, 0);
});

test("launch_agent: per-session cap defaults to 3, fourth launch is blocked without a request", async () => {
  const { api, box } = await setup({ "POST /v1/agents": launchOk });
  for (let i = 0; i < 3; i += 1) assert.equal((await box.call("launch_agent", LAUNCH)).isError, false);
  const blocked = await box.call("launch_agent", LAUNCH);
  assert.equal(blocked.isError, true);
  assert.equal(blocked.data.error.code, "launch_cap_reached");
  assert.equal(blocked.data.error.launchCap, 3);
  assert.equal(api.requests.length, 3);
});

test("launch cap is env-configurable and invalid values fall back to 3", async () => {
  assert.equal(resolveLaunchCap({ CURSOR_MAX_LAUNCHES_PER_SESSION: "1" }), 1);
  assert.equal(resolveLaunchCap({ CURSOR_MAX_LAUNCHES_PER_SESSION: "0" }), 0);
  for (const v of ["-1", "abc", "999", "2.5x"]) assert.equal(resolveLaunchCap({ CURSOR_MAX_LAUNCHES_PER_SESSION: v }), 3);
  assert.equal(resolveLaunchCap({}), 3);
  const { api, box } = await setup({ "POST /v1/agents": launchOk }, { CURSOR_MAX_LAUNCHES_PER_SESSION: "1" });
  assert.equal((await box.call("launch_agent", LAUNCH)).isError, false);
  assert.equal((await box.call("launch_agent", LAUNCH)).data.error.code, "launch_cap_reached");
  assert.equal(api.requests.length, 1);
});

test("launch_agent: a definite 4xx refunds the slot, a 5xx does not", async () => {
  let n = 0;
  const { box } = await setup(
    { "POST /v1/agents": () => (++n === 1 ? { status: 400, body: { code: "validation_error", message: "bad repo" } } : { status: 500, body: { error: "Internal Server Error" } }) },
    { CURSOR_MAX_LAUNCHES_PER_SESSION: "2" },
  );
  const a = await box.call("launch_agent", LAUNCH);
  assert.equal(a.data.error.code, "validation_error");
  assert.equal(a.data.error.retryable, false);
  assert.equal(box.state().launchesUsed, 0);
  const b = await box.call("launch_agent", LAUNCH);
  assert.equal(b.data.error.code, "server_error");
  assert.equal(b.data.error.retryable, true);
  assert.equal(box.state().launchesUsed, 1);
});

test("launch_agent: concurrent calls cannot race past the cap", async () => {
  const { api, box } = await setup({ "POST /v1/agents": async () => ({ ...launchOk(), delayMs: 40 }) }, { CURSOR_MAX_LAUNCHES_PER_SESSION: "2" });
  const results = await Promise.all([1, 2, 3, 4].map(() => box.call("launch_agent", LAUNCH)));
  assert.equal(results.filter((r) => !r.isError).length, 2);
  assert.equal(api.requests.length, 2);
});

test("get_status: agent plus latest run, nextPollSeconds hint, terminal flag", async () => {
  const { api, box } = await setup({
    [`GET /v1/agents/${AGENT_ID}`]: { body: agentFixture() },
    [`GET /v1/agents/${AGENT_ID}/runs/${RUN_ID}`]: { body: runFixture({ status: "RUNNING" }) },
  });
  const out = await box.call("get_status", { agentId: AGENT_ID });
  assert.equal(out.isError, false);
  assert.equal(out.data.agent.id, AGENT_ID);
  assert.equal(out.data.run.status, "RUNNING");
  assert.equal(out.data.terminal, false);
  assert.equal(out.data.nextPollSeconds, 20);
  assert.deepEqual(api.requests.map((r) => r.path), [`/v1/agents/${AGENT_ID}`, `/v1/agents/${AGENT_ID}/runs/${RUN_ID}`]);
});

test("get_status: finished run returns result and git, nextPollSeconds null", async () => {
  const git = { branches: [{ repoUrl: "github.com/example-org/example-repo", branch: "cursor/add-readme-a1b2" }] };
  const { box } = await setup({
    [`GET /v1/agents/${AGENT_ID}`]: { body: agentFixture({ status: "IDLE" }) },
    [`GET /v1/agents/${AGENT_ID}/runs/${RUN_ID}`]: { body: runFixture({ status: "FINISHED", durationMs: 1234, result: "Done", git }) },
  });
  const out = await box.call("get_status", { agentId: AGENT_ID });
  assert.equal(out.data.terminal, true);
  assert.equal(out.data.nextPollSeconds, null);
  assert.equal(out.data.run.result, "Done");
  assert.equal(out.data.run.durationMs, 1234);
  assert.deepEqual(out.data.run.git, git);
});

test("get_status: long result is truncated and flagged; explicit runId is used; run lookup failure is reported", async () => {
  const { api, box } = await setup({
    [`GET /v1/agents/${AGENT_ID}`]: { body: agentFixture() },
    [`GET /v1/agents/${AGENT_ID}/runs/${RUN_ID_2}`]: { body: runFixture({ id: RUN_ID_2, status: "FINISHED", result: "x".repeat(25000) }) },
    [`GET /v1/agents/${AGENT_ID}/runs/${RUN_ID}`]: { status: 404, body: { code: "run_not_found", message: "no such run" } },
  });
  const a = await box.call("get_status", { agentId: AGENT_ID, runId: RUN_ID_2 });
  assert.equal(a.data.run.result.length, 20000);
  assert.equal(a.data.run.resultTruncated, true);
  assert.equal(api.requests[1].path, `/v1/agents/${AGENT_ID}/runs/${RUN_ID_2}`);
  const b = await box.call("get_status", { agentId: AGENT_ID });
  assert.equal(b.isError, false);
  assert.equal(b.data.run, null);
  assert.equal(b.data.runError.code, "run_not_found");
});

test("get_status: rejects ids that could alter the request path", async () => {
  const { api, box } = await setup();
  for (const agentId of ["../agents", "bc-1/runs", "bc 1", "", undefined, 42]) {
    const out = await box.call("get_status", { agentId });
    assert.equal(out.isError, true);
    assert.equal(out.data.error.code, "invalid_input");
  }
  assert.equal(api.requests.length, 0);
});

test("get_status: 404 and 401 are mapped to structured errors", async () => {
  const { box } = await setup({ [`GET /v1/agents/${AGENT_ID}`]: { status: 404, body: { error: "Not Found", message: "agent not found" } } });
  const a = await box.call("get_status", { agentId: AGENT_ID });
  assert.equal(a.data.error.status, 404);
  assert.equal(a.data.error.code, "not_found");
  assert.equal(a.data.error.retryable, false);
  const { box: box2 } = await setup({ [`GET /v1/agents/${AGENT_ID}`]: { status: 401, body: { error: "Unauthorized", message: "Invalid API key" } } });
  assert.equal((await box2.call("get_status", { agentId: AGENT_ID })).data.error.code, "unauthorized");
});

test("followup: POST /v1/agents/{id}/runs returns the new runId", async () => {
  const { api, box } = await setup({ [`POST /v1/agents/${AGENT_ID}/runs`]: { status: 201, body: { run: runFixture({ id: RUN_ID_2, status: "CREATING" }) } } });
  const out = await box.call("followup", { agentId: AGENT_ID, prompt: "Also add tests", mode: "agent" });
  assert.equal(out.isError, false);
  assert.equal(out.data.runId, RUN_ID_2);
  assert.deepEqual(api.requests[0].body, { prompt: { text: "Also add tests" }, mode: "agent" });
});

test("followup: 409 agent_busy (explicit code) maps to a structured retryable error", async () => {
  const { box } = await setup({ [`POST /v1/agents/${AGENT_ID}/runs`]: { status: 409, body: { code: "agent_busy", message: "run active" } } });
  const out = await box.call("followup", { agentId: AGENT_ID, prompt: "more" });
  assert.equal(out.isError, true);
  assert.equal(out.data.error.code, "agent_busy");
  assert.equal(out.data.error.status, 409);
  assert.equal(out.data.error.retryable, true);
  assert.match(out.data.error.hint, /get_status/);
  assert.ok(out.data.error.nextPollSeconds > 0);
});

test("followup: 409 in the nested error shape and 409 without a code both map to agent_busy", async () => {
  for (const body of [{ error: { code: "agent_busy", message: "busy" } }, { error: "Conflict", message: "busy" }, { message: "busy" }]) {
    const { box } = await setup({ [`POST /v1/agents/${AGENT_ID}/runs`]: { status: 409, body } });
    const out = await box.call("followup", { agentId: AGENT_ID, prompt: "more" });
    assert.equal(out.data.error.code, "agent_busy", JSON.stringify(body));
  }
});

test("followup: a different 409 code is not mislabelled as agent_busy", async () => {
  const { box } = await setup({ [`POST /v1/agents/${AGENT_ID}/runs`]: { status: 409, body: { code: "something_else", message: "x" } } });
  assert.equal((await box.call("followup", { agentId: AGENT_ID, prompt: "more" })).data.error.code, "something_else");
});

test("list_agents: query params, pagination cursor, absent nextCursor means done", async () => {
  const { api, box } = await setup({
    "GET /v1/agents": (req) => (req.query.cursor ? { body: { items: [{ id: "bc-2" }] } } : { body: { items: [{ id: "bc-1" }], nextCursor: "bc-2" } }),
  });
  const a = await box.call("list_agents", { limit: 5, includeArchived: false });
  assert.deepEqual(a.data, { items: [{ id: "bc-1" }], nextCursor: "bc-2" });
  assert.deepEqual(api.requests[0].query, { limit: "5", includeArchived: "false" });
  const b = await box.call("list_agents", { cursor: "bc-2" });
  assert.deepEqual(b.data, { items: [{ id: "bc-2" }] });
  assert.equal(api.requests[1].query.cursor, "bc-2");
  for (const limit of [0, 101, 1.5, "5"]) assert.equal((await box.call("list_agents", { limit })).data.error.code, "invalid_input");
});

test("cancel: needs confirm:true; resolves latestRunId; POSTs the cancel path", async () => {
  const { api, box } = await setup({
    [`GET /v1/agents/${AGENT_ID}`]: { body: agentFixture() },
    [`POST /v1/agents/${AGENT_ID}/runs/${RUN_ID}/cancel`]: { body: { id: RUN_ID } },
  });
  const noConfirm = await box.call("cancel", { agentId: AGENT_ID });
  assert.equal(noConfirm.data.error.code, "confirmation_required");
  assert.equal(api.requests.length, 0);
  const out = await box.call("cancel", { agentId: AGENT_ID, confirm: true });
  assert.deepEqual(out.data, { agentId: AGENT_ID, runId: RUN_ID, cancelled: true });
  assert.deepEqual(api.requests.map((r) => `${r.method} ${r.path}`), [`GET /v1/agents/${AGENT_ID}`, `POST /v1/agents/${AGENT_ID}/runs/${RUN_ID}/cancel`]);
});

test("cancel: explicit runId skips the lookup; 409 maps to run_not_cancellable", async () => {
  const { api, box } = await setup({ [`POST /v1/agents/${AGENT_ID}/runs/${RUN_ID_2}/cancel`]: { status: 409, body: { code: "run_not_cancellable", message: "terminal" } } });
  const out = await box.call("cancel", { agentId: AGENT_ID, runId: RUN_ID_2, confirm: true });
  assert.equal(out.data.error.code, "run_not_cancellable");
  assert.equal(out.data.error.retryable, false);
  assert.equal(api.requests.length, 1);
});

test("get_artifacts: lists artifacts, then fetches a presigned download link", async () => {
  const { api, box } = await setup({
    [`GET /v1/agents/${AGENT_ID}/artifacts`]: { body: { items: [{ path: "artifacts/screenshot.png", sizeBytes: 12345, updatedAt: "2026-10-10T00:00:00.000Z" }] } },
    [`GET /v1/agents/${AGENT_ID}/artifacts/download`]: { body: { url: "https://artifacts.example.org/obj?sig=abc", expiresAt: "2026-10-10T01:00:00.000Z" } },
  });
  const list = await box.call("get_artifacts", { agentId: AGENT_ID });
  assert.equal(list.data.items[0].path, "artifacts/screenshot.png");
  const dl = await box.call("get_artifacts", { agentId: AGENT_ID, path: "artifacts/screenshot.png" });
  assert.equal(dl.data.url, "https://artifacts.example.org/obj?sig=abc");
  assert.equal(api.requests[1].query.path, "artifacts/screenshot.png");
  for (const path of ["/etc/passwd", "artifacts/../secret", "other/x.png", "artifacts\\x"]) {
    assert.equal((await box.call("get_artifacts", { agentId: AGENT_ID, path })).data.error.code, "invalid_input", path);
  }
});

test("429 carries retryAfterSeconds and is retryable; no automatic retry happens", async () => {
  const { api, box } = await setup({ "GET /v1/agents": { status: 429, headers: { "retry-after": "30" }, body: { error: "Too Many Requests", message: "Rate limit exceeded" } } });
  const out = await box.call("list_agents", {});
  assert.equal(out.data.error.code, "rate_limited");
  assert.equal(out.data.error.retryAfterSeconds, 30);
  assert.equal(out.data.error.retryable, true);
  assert.equal(api.requests.length, 1);
});

test("request timeout is enforced", async () => {
  const { box } = await setup({ "GET /v1/agents": { delayMs: 800, body: { items: [] } } }, { CURSOR_REQUEST_TIMEOUT_MS: "150" });
  const out = await box.call("list_agents", {});
  assert.equal(out.data.error.code, "timeout");
  assert.equal(out.data.error.retryable, true);
});

test("timeout while reading the body is timeout, not internal_error", async () => {
  const { box } = await setup({ "GET /v1/agents": { bodyDelayMs: 800, body: { items: [] } } }, { CURSOR_REQUEST_TIMEOUT_MS: "150" });
  const out = await box.call("list_agents", {});
  assert.equal(out.data.error.code, "timeout");
  assert.equal(out.data.error.retryable, true);
});

test("missing or unexpanded API key: structured error, no request", async () => {
  for (const key of [undefined, "", "${CURSOR_API_KEY}"]) {
    const api = await startFakeApi({ "GET /v1/agents": { body: { items: [] } } });
    open.push(api);
    const env = { CURSOR_API_BASE_URL: api.baseUrl };
    if (key !== undefined) env.CURSOR_API_KEY = key;
    const out = await createToolbox({ env }).call("list_agents", {});
    assert.equal(out.data.error.code, "missing_api_key");
    assert.equal(api.requests.length, 0);
  }
  assert.throws(() => resolveApiKey({}), /CURSOR_API_KEY/);
});

test("base URL must be https unless loopback", () => {
  assert.equal(resolveBaseUrl({}), "https://api.cursor.com");
  assert.equal(resolveBaseUrl({ CURSOR_API_BASE_URL: "http://127.0.0.1:9/" }), "http://127.0.0.1:9");
  assert.throws(() => resolveBaseUrl({ CURSOR_API_BASE_URL: "http://api.example.org" }), /https/);
  assert.throws(() => resolveBaseUrl({ CURSOR_API_BASE_URL: "not a url" }), /valid URL/);
});

test("redaction: the key never appears in an error, even when the server echoes it back", async () => {
  const echo = { status: 400, body: { code: "bad_request", message: `Invalid key ${FAKE_KEY} and header Bearer ${FAKE_KEY}` } };
  const { box, env } = await setup({ "GET /v1/agents": echo });
  const out = await box.call("list_agents", {});
  const text = JSON.stringify(out);
  assert.ok(!text.includes(FAKE_KEY), text);
  assert.ok(!text.includes(Buffer.from(`${FAKE_KEY}:`).toString("base64")));
  assert.match(out.data.error.message, /\[REDACTED\]/);
  assert.equal(redact(`x ${FAKE_KEY} y`, env), "x [REDACTED] y");
  assert.ok(!redact(`Basic ${Buffer.from(`${FAKE_KEY}:`).toString("base64")}`, env).includes(Buffer.from(`${FAKE_KEY}:`).toString("base64")));
});

test("redaction: key-shaped strings are scrubbed even when they are not the configured key", () => {
  const other = `crsr_${"z9y8x7w6".repeat(4)}`;
  assert.ok(!redact(`token ${other}`, {}).includes(other));
  assert.ok(!redact(`Authorization: Bearer ${"Qw3rTy".repeat(5)}`, {}).includes("Qw3rTy"));
});

test("network failure message is redacted and structured", async () => {
  const env = { CURSOR_API_KEY: FAKE_KEY, CURSOR_API_BASE_URL: "http://127.0.0.1:9" };
  const out = await createToolbox({ env, client: undefined }).call("list_agents", {});
  assert.equal(out.isError, true);
  assert.ok(["network_error", "timeout"].includes(out.data.error.code));
  assert.ok(!JSON.stringify(out).includes(FAKE_KEY));
});

test("unknown tool is reported to the caller and sends nothing", async () => {
  const { api, box } = await setup();
  assert.deepEqual(await box.call("delete_agent", { agentId: AGENT_ID }), { unknownTool: true });
  assert.equal(api.requests.length, 0);
});

test("nextPollSeconds hints", () => {
  assert.equal(nextPollSeconds("CREATING"), 5);
  assert.equal(nextPollSeconds("RUNNING"), 20);
  for (const s of ["FINISHED", "ERROR", "CANCELLED", "EXPIRED"]) assert.equal(nextPollSeconds(s, "ACTIVE"), null);
  assert.equal(nextPollSeconds(undefined, "ACTIVE"), 10);
  assert.equal(nextPollSeconds(undefined, "IDLE"), null);
});

test("parseErrorBody handles documented shapes and non-JSON", () => {
  assert.deepEqual(parseErrorBody('{"code":"agent_busy","message":"m"}').code, "agent_busy");
  assert.deepEqual(parseErrorBody('{"error":{"code":"c","message":"m"}}').code, "c");
  assert.equal(parseErrorBody('{"error":"Unauthorized","message":"Invalid API key"}').message, "Invalid API key");
  assert.equal(parseErrorBody("<html>oops</html>").message, "<html>oops</html>");
  assert.equal(parseErrorBody("").message, null);
});

test("launch_agent accepts a GitLab repo URL", async () => {
  const { api, box } = await setup({ "POST /v1/agents": launchOk });
  const repoUrl = "https://gitlab.example.com/group/repo";
  const out = await box.call("launch_agent", { ...LAUNCH, repoUrl });
  assert.equal(out.isError, false);
  assert.equal(api.requests[0].body.repos[0].url, repoUrl);
});

test("403 without a code maps to forbidden", async () => {
  const { box } = await setup({
    [`GET /v1/agents/${AGENT_ID}`]: { status: 403, body: { error: "Forbidden", message: "not allowed" } },
  });
  const out = await box.call("get_status", { agentId: AGENT_ID });
  assert.equal(out.data.error.status, 403);
  assert.equal(out.data.error.code, "forbidden");
  assert.equal(out.data.error.retryable, false);
});

test("repo allow-list: unset allows all; a miss is repo_not_allowed and sends nothing", async () => {
  assert.equal(parseAllowedRepoPrefixes({}), null);
  assert.equal(parseAllowedRepoPrefixes({ CURSOR_CLOUD_AGENTS_ALLOWED_REPOS: "  " }), null);
  const { api, box } = await setup(
    { "POST /v1/agents": launchOk },
    { CURSOR_CLOUD_AGENTS_ALLOWED_REPOS: "https://github.com/example-org/" },
  );
  const blocked = await box.call("launch_agent", {
    ...LAUNCH,
    repoUrl: "https://gitlab.example.com/group/repo",
  });
  assert.equal(blocked.data.error.code, "repo_not_allowed");
  assert.equal(api.requests.length, 0);
  const ok = await box.call("launch_agent", LAUNCH);
  assert.equal(ok.isError, false);
  assert.equal(api.requests.length, 1);
});

test("repo allow-list rejects prefix bypasses and still allows a real repo", async () => {
  const env = { CURSOR_CLOUD_AGENTS_ALLOWED_REPOS: "https://github.com/example-org/example-repo" };
  const { api, box } = await setup({ "POST /v1/agents": launchOk }, env);
  const bypasses = [
    "https://github.com/example-org/example-repo/../../evil/other",
    "https://github.com/example-org/../evil/example-repo",
    "https://github.com.evil/example-org/example-repo",
    "https://github.com/example-org/example-repo-evil",
    "https://evil.github.com/example-org/example-repo",
  ];
  for (const repoUrl of bypasses) {
    const blocked = await box.call("launch_agent", { ...LAUNCH, repoUrl });
    assert.equal(blocked.data.error.code, "repo_not_allowed", repoUrl);
  }
  assert.equal(api.requests.length, 0);
  const allowed = await box.call("launch_agent", {
    ...LAUNCH,
    repoUrl: "https://github.com/example-org/example-repo",
  });
  assert.equal(allowed.isError, false);
  assert.equal(api.requests.length, 1);
});
