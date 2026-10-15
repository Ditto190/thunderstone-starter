import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { once } from 'node:events';
import { spawn, spawnSync } from 'node:child_process';
import test from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const SCRIPT = new URL('../src/chatgpt-stdio-adapter.mjs', import.meta.url).pathname;
const FIXTURE_BEARER = 'dummy-fixture-dummy-fixture-dummy-xx';
const TOOLS = [
  { name: 'post_task', description: 'post task', inputSchema: { type: 'object', properties: {}, additionalProperties: false } },
  { name: 'get_task', description: 'get task', inputSchema: { type: 'object', properties: {}, additionalProperties: false } },
  { name: 'post_receipt', description: 'post receipt', inputSchema: { type: 'object', properties: {}, additionalProperties: false } },
  { name: 'list_tasks', description: 'list tasks', inputSchema: { type: 'object', properties: {}, additionalProperties: false } },
];

function send(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

async function fixture(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ts-stdio-adapter-'));
  const tokenDir = path.join(root, '.config', 'thunderstone-bridge', 'tokens');
  fs.mkdirSync(tokenDir, { recursive: true, mode: 0o700 });
  fs.writeFileSync(path.join(tokenDir, 'chatgpt.token'), FIXTURE_BEARER + '\n', { mode: 0o600 });
  const seen = [];
  const server = http.createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const body = raw ? JSON.parse(raw) : null;
    seen.push({ method: req.method, url: req.url, authorization: req.headers.authorization, body });
    if (req.url !== '/mcp') return send(res, 404, { error: 'not found' });
    if (body?.method === 'notifications/initialized') { res.writeHead(202); return res.end(); }
    if (body?.method === 'initialize') {
      return send(res, 200, { jsonrpc: '2.0', id: body.id, result: {
        protocolVersion: '2025-11-25', capabilities: { tools: {} },
        serverInfo: { name: 'test-bridge', version: '1.0.0' },
      }});
    }
    if (body?.method === 'tools/list') {
      return send(res, 200, { jsonrpc: '2.0', id: body.id, result: { tools: TOOLS } });
    }
    if (body?.method === 'tools/call') {
      return send(res, 200, { jsonrpc: '2.0', id: body.id, result: {
        content: [{ type: 'text', text: JSON.stringify({ count: 1, tasks: [{ id: 't-test-1' }] }) }],
      }});
    }
    if (body?.method === 'ping') return send(res, 200, { jsonrpc: '2.0', id: body.id, result: {} });
    return send(res, 200, { jsonrpc: '2.0', id: body?.id ?? null, result: {} });
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const env = { ...process.env, HOME: root, THUNDERSTONE_BRIDGE_URL: `http://127.0.0.1:${server.address().port}/mcp` };
  try { await run({ env, seen, root, tokenDir }); }
  finally {
    server.close();
    server.closeAllConnections?.();
    fs.rmSync(root, { recursive: true, force: true });
  }
}
test('exposes the four shared tools over stdio and forwards calls with the ChatGPT credential', async () => {
  await fixture(async ({ env, seen }) => {
    const stderr = [];
    const transport = new StdioClientTransport({ command: process.execPath, args: [SCRIPT], env });
    transport.stderr?.setEncoding('utf8').on('data', chunk => stderr.push(chunk));
    const client = new Client({ name: 'adapter-test-client', version: '1.0.0' });
    try {
      await client.connect(transport);
      const listing = await client.listTools();
      assert.deepEqual(listing.tools.map(t => t.name).sort(), ['get_task', 'list_tasks', 'post_receipt', 'post_task']);
      const result = await client.callTool({ name: 'list_tasks', arguments: {} });
      assert.equal(result.isError, undefined);
      const payload = JSON.parse(result.content.find(item => item.type === 'text').text);
      assert.equal(payload.count, 1);
      assert.equal(payload.tasks[0].id, 't-test-1');
      assert.ok(seen.length >= 3, 'adapter should initialize and make tool calls upstream');
      assert.ok(seen.every(entry => entry.authorization === `Bearer ${FIXTURE_BEARER}`), 'every upstream request must use the ChatGPT-specific credential');
      assert.ok(!stderr.join('').includes(FIXTURE_BEARER), 'adapter logs must not leak credential');
    } finally {
      await client.close().catch(() => {});
    }
  });
});

test('rejects a non-loopback plain-HTTP endpoint before any network request', async () => {
  await fixture(({ env, seen, root }) => {
    env.THUNDERSTONE_BRIDGE_URL = 'http://example.invalid/mcp';
    const result = spawnSync(process.execPath, [SCRIPT], { env, encoding: 'utf8', timeout: 3000 });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /HTTPS|loopback|plain HTTP/i);
    assert.equal(result.stdout, '');
    assert.equal(seen.length, 0, 'no request may be sent to an insecure non-loopback endpoint');
  });
});

test('rejects a credential file with group/other permissions', async () => {
  await fixture(({ env, root, tokenDir }) => {
    fs.chmodSync(path.join(tokenDir, 'chatgpt.token'), 0o644);
    const result = spawnSync(process.execPath, [SCRIPT], { env, encoding: 'utf8', timeout: 3000 });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /permissions|0600|0400/i);
  });
});
