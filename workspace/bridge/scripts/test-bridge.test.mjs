import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const PORT = process.env.BRIDGE_PORT || process.env.PORT || '3999';
if (PORT === '3847') throw new Error('refusing to test against port 3847');
const BASE = `http://127.0.0.1:${PORT}`;
const TOKEN_DIR = path.join(process.env.HOME, '.config/thunderstone-bridge/tokens');
const THUNDERSTONE_ROOT = process.env.THUNDERSTONE_ROOT ?? path.join(path.sep, 'workspace', 'thunderstone');
const AUDIT_LOG = path.join(THUNDERSTONE_ROOT, 'state', 'bridge-audit.log');
let requestId = 0;

function token(agent) {
  const p = path.join(TOKEN_DIR, agent + '.token');
  assert.ok(fs.existsSync(p), 'missing local test credential for ' + agent);
  return fs.readFileSync(p, 'utf8').trim();
}

async function parseResponse(response) {
  const raw = await response.text();
  if (!raw) return null;
  if (response.headers.get('content-type')?.includes('text/event-stream')) {
    const data = raw.split(/\r?\n/).find((line) => line.startsWith('data: '));
    assert.ok(data, 'expected an MCP SSE data event');
    return JSON.parse(data.slice(6));
  }
  return JSON.parse(raw);
}

async function rpc(agent, method, params = {}) {
  const response = await fetch(BASE + '/mcp', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      accept: 'application/json, text/event-stream',
      authorization: 'Bearer ' + token(agent),
    },
    body: JSON.stringify({ jsonrpc: '2.0', id: ++requestId, method, params }),
  });
  return { response, body: await parseResponse(response) };
}

async function callTool(agent, name, args = {}) {
  const { response, body } = await rpc(agent, 'tools/call', { name, arguments: args });
  assert.equal(response.status, 200, name + ' HTTP status');
  assert.ok(body?.result, name + ' must return an MCP result');
  const content = body.result.content?.find((item) => item.type === 'text')?.text;
  assert.ok(content, name + ' must return text content');
  return { result: body.result, value: JSON.parse(content) };
}

test('bridge HTTP auth, MCP tools, task isolation, receipts and audit', async () => {
  const health = await fetch(BASE + '/health');
  assert.equal(health.status, 401, 'health requires auth');
  const health2 = await fetch(BASE + '/health', { headers: { authorization: 'Bearer ' + token('grok-bot') } });
  assert.equal(health2.status, 200);
  assert.deepEqual(await health2.json(), { ok: true });

  const unauth = await fetch(BASE + '/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json, text/event-stream' },
    body: JSON.stringify({ jsonrpc: '2.0', id: ++requestId, method: 'tools/list', params: {} }),
  });
  assert.equal(unauth.status, 401, 'unauthenticated MCP requests must be rejected');

  const listed = await rpc('grok-bot', 'tools/list');
  assert.equal(listed.response.status, 200);
  const names = listed.body.result.tools.map((tool) => tool.name).sort();
  assert.deepEqual(names, ['get_task', 'list_tasks', 'post_receipt', 'post_task']);

  let taskId;
  try {
    const created = await callTool('grok-bot', 'post_task', {
      to: 'cursor', ask: 'bridge integration test: verify task isolation'
    });
    assert.equal(created.result.isError, false);
    taskId = created.value.id;
    assert.match(taskId, /^t[a-z0-9]+$/);

    const hidden = await callTool('chatgpt', 'get_task', { id: taskId });
    assert.equal(hidden.result.isError, true);
    assert.equal(hidden.value.error, 'not_found');

    const unrelatedList = await callTool('chatgpt', 'list_tasks');
    assert.equal(unrelatedList.result.isError, false);
    assert.equal(unrelatedList.value.tasks.some((task) => task.id === taskId), false);

    const visible = await callTool('cursor', 'get_task', { id: taskId });
    assert.equal(visible.result.isError, false);
    assert.equal(visible.value.id, taskId);

    const wrongReceipt = await callTool('grok-bot', 'post_receipt', {
      id: taskId, summary: 'must be rejected because sender is not assignee'
    });
    assert.equal(wrongReceipt.result.isError, true);

    const receipt = await callTool('cursor', 'post_receipt', {
      id: taskId, summary: 'integration test verified task isolation'
    });
    assert.equal(receipt.result.isError, false);
    assert.equal(receipt.value.status, 'done');

    const done = await callTool('cursor', 'list_tasks', { status: 'done' });
    assert.ok(done.value.tasks.some((task) => task.id === taskId && task.has_receipt));
  } finally {
    if (taskId) {
      const taskPath = path.join(THUNDERSTONE_ROOT, 'handoffs', 'tasks', taskId + '.json');
      try { fs.unlinkSync(taskPath); } catch {}
    }
  }

  assert.ok(fs.existsSync(AUDIT_LOG), 'audit log must be created');
  const records = fs.readFileSync(AUDIT_LOG, 'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  assert.ok(records.some((entry) => entry.result === 'auth_fail' && entry.agent === 'anonymous'));
  assert.ok(records.some((entry) => entry.tool === 'get_task' && entry.result === 'deny' && entry.detail === 'isolation'));
  assert.ok(records.some((entry) => entry.tool === 'post_receipt' && entry.result === 'ok'));
  assert.ok(records.every((entry) => !JSON.stringify(entry).includes('Bearer ')), 'audit must not contain bearer tokens');
});

const H = { 'content-type': 'application/json', accept: 'application/json, text/event-stream' };
const TASKS = path.join(THUNDERSTONE_ROOT, 'handoffs', 'tasks');
async function raw(auth, body, extra = {}, url = '/mcp', method = 'POST') {
  const headers = { ...H, ...extra };
  if (auth !== undefined) headers.authorization = auth;
  return fetch(BASE + url, { method, headers, body: method === 'GET' ? undefined : body });
}
const LIST = JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} });

test('auth: missing token -> 401', async () => { assert.equal((await raw(undefined, LIST)).status, 401); });
test('auth: empty header -> 401', async () => { assert.equal((await raw('', LIST)).status, 401); });
test("auth: 'Bearer ' only -> 401", async () => { assert.equal((await raw('Bearer ', LIST)).status, 401); });
test('auth: invalid token -> 401', async () => { assert.equal((await raw('Bearer invalid-' + 'x'.repeat(40), LIST)).status, 401); });
test('auth: wrong scheme -> 401', async () => { assert.equal((await raw('Basic ' + token('cursor'), LIST)).status, 401); });
test('routes: non-/mcp unauth -> 401, auth -> 404', async () => {
  for (const u of ['/', '/admin', '/mcp/../etc/passwd', '/handoffs/tasks']) {
    assert.equal((await raw(undefined, null, {}, u, 'GET')).status, 401, u);
    assert.equal((await raw('Bearer ' + token('cursor'), null, {}, u, 'GET')).status, 404, u);
  }
});
test('malformed JSON-RPC body rejected', async () => {
  const r = await raw('Bearer ' + token('cursor'), '{not json');
  assert.ok(r.status >= 400 && r.status < 500, 'status ' + r.status);
});
test('wrong content-type rejected', async () => {
  const r = await raw('Bearer ' + token('cursor'), LIST, { 'content-type': 'text/plain' });
  assert.ok(r.status >= 400 && r.status < 500, 'status ' + r.status);
});
test('oversized body rejected', async () => {
  const big = JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'post_task', arguments: { to: 'cursor', ask: 'x', payload: 'A'.repeat(2 * 1024 * 1024) } } });
  const r = await raw('Bearer ' + token('grok-bot'), big);
  assert.ok(r.status === 413 || r.status === 400, 'status ' + r.status);
});
test('isolation: B get_task / post_receipt on A->C task denied', async () => {
  const c = await callTool('grok-bot', 'post_task', { to: 'cursor', ask: 'iso test' });
  const id = c.value.id;
  try {
    const g = await callTool('claude', 'get_task', { id });
    assert.equal(g.result.isError, true);
    const pr = await callTool('claude', 'post_receipt', { id, summary: 'hijack' });
    assert.equal(pr.result.isError, true);
    const t = JSON.parse(fs.readFileSync(TASKS + '/' + id + '.json', 'utf8'));
    assert.equal(t.status, 'open'); assert.equal(t.receipt, null);
  } finally { try { fs.unlinkSync(TASKS + '/' + id + '.json'); } catch {} }
});
test('traversal ids rejected (../, encoded, absolute)', async () => {
  for (const id of ['../../etc/passwd', '..', '%2e%2e%2fetc%2fpasswd', '/etc/passwd', 'a/../../b', '..\\x', '.hidden']) {
    for (const tool of ['get_task', 'post_receipt']) {
      const args = tool === 'get_task' ? { id } : { id, summary: 's' };
      const r = await callTool('cursor', tool, args);
      assert.equal(r.result.isError, true, tool + ' ' + id);
    }
  }
});
test('symlink in handoffs/tasks not followed', async () => {
  const id = 'tsymlinktest' + Date.now().toString(36);
  const lp = TASKS + '/' + id + '.json';
  const target = '/tmp/' + id + '-outside.json';
  fs.writeFileSync(target, JSON.stringify({ id, from: 'grok-bot', to: 'cursor', status: 'open', receipt: null, ask: 'SECRET-OUTSIDE' }));
  fs.symlinkSync(target, lp);
  try {
    const r = await callTool('cursor', 'get_task', { id });
    assert.equal(r.result.isError, true);
    assert.ok(!JSON.stringify(r.value).includes('SECRET-OUTSIDE'));
    const l = await callTool('cursor', 'list_tasks');
    assert.ok(!l.value.tasks.some((t) => t.id === id));
  } finally { fs.unlinkSync(lp); fs.unlinkSync(target); }
});
