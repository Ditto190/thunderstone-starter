#!/usr/bin/env node
// Stdio MCP adapter for OpenAI Secure MCP Tunnel. Routes using ChatGPT's own
// least-privilege bearer identity; never writes the credential or raw errors.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import * as z from 'zod/v4';

const REQUIRED_TOOLS = ['post_task', 'get_task', 'post_receipt', 'list_tasks'];
const AGENTS = ['grok-bot', 'cursor', 'chatgpt', 'claude', 'perplexity'];
const MAX_ASK = 300;
const MAX_PAYLOAD = 64 * 1024;
const MAX_RECEIPT = 2 * 1024;

function resolveEndpoint() {
  const raw = process.env.THUNDERSTONE_BRIDGE_URL || 'http://127.0.0.1:3847/mcp';
  let url;
  try { url = new URL(raw); } catch { throw new Error('invalid bridge endpoint URL'); }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash || url.pathname !== '/mcp') {
    throw new Error('bridge endpoint must be an http(s) URL ending exactly in /mcp');
  }
  const loopback = ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname);
  if (url.protocol !== 'https:' && !loopback) {
    throw new Error('refusing plain HTTP to a non-loopback endpoint; HTTPS is required');
  }
  return url;
}

function readCredential() {
  const tokenPath = path.join(os.homedir(), '.config', 'thunderstone-bridge', 'tokens', 'chatgpt.token');
  let stat;
  try { stat = fs.lstatSync(tokenPath); } catch { throw new Error('ChatGPT bridge credential file is missing'); }
  if (stat.isSymbolicLink() || !stat.isFile()) throw new Error('ChatGPT credential path must be a regular non-symlink file');
  if (process.platform !== 'win32' && (stat.mode & 0o077) !== 0) {
    throw new Error('ChatGPT credential file permissions must be 0600 or stricter');
  }
  const token = fs.readFileSync(tokenPath, 'utf8').trim();
  if (token.length < 32 || /\s/.test(token)) throw new Error('ChatGPT bridge credential is malformed');
  return token;
}

function proxyTool(remoteClient, name) {
  return async (args) => {
    try {
      return await remoteClient.callTool({ name, arguments: args });
    } catch {
      return { isError: true, content: [{ type: 'text', text: 'Shared bridge call failed; inspect the redacted adapter/bridge health evidence.' }] };
    }
  };
}

async function main() {
  const endpoint = resolveEndpoint();
  const token = readCredential();
  const remoteClient = new Client({ name: 'thunderstone-chatgpt-upstream', version: '1.0.0' });
  const remoteTransport = new StreamableHTTPClientTransport(endpoint, {
    requestInit: { headers: { Authorization: `Bearer ${token}` } },
  });
  try {
    await remoteClient.connect(remoteTransport);
    const discovered = await remoteClient.listTools();
    const names = new Set((discovered.tools ?? []).map(tool => tool.name));
    const missing = REQUIRED_TOOLS.filter(name => !names.has(name));
    if (missing.length) throw new Error('upstream bridge does not expose required shared tools');
  } catch (error) {
    let detail = error instanceof Error ? `${error.name}: ${error.message}` : 'unknown error';
    detail = detail.replaceAll(token, '<redacted>').replace(/Bearer\s+\S+/gi, 'Bearer <redacted>').slice(0, 240);
    console.error(`thunderstone-chatgpt-stdio-adapter: upstream bridge handshake failed (${detail})`);
    process.exitCode = 78;
    await remoteClient.close().catch(() => {});
    return;
  }
  const server = new McpServer({ name: 'thunderstone-chatgpt-bridge', version: '1.0.0' });
  server.registerTool('post_task', {
    description: 'Post a shared handoff task to another registered agent. Confined to handoffs.',
    inputSchema: {
      to: z.enum(AGENTS),
      ask: z.string().min(1).max(MAX_ASK),
      payload: z.string().max(MAX_PAYLOAD).optional(),
      out: z.string().max(200).optional(),
      due: z.string().max(80).optional(),
      pri: z.boolean().optional(),
    },
  }, proxyTool(remoteClient, 'post_task'));

  server.registerTool('get_task', {
    description: 'Read one task if the authenticated ChatGPT identity is its sender or recipient.',
    inputSchema: { id: z.string().min(1).max(64) },
  }, proxyTool(remoteClient, 'get_task'));

  server.registerTool('post_receipt', {
    description: 'Post completion receipt; bridge enforces that only the assigned recipient can complete a task.',
    inputSchema: {
      id: z.string().min(1).max(64),
      summary: z.string().min(1).max(MAX_RECEIPT),
    },
  }, proxyTool(remoteClient, 'post_receipt'));

  server.registerTool('list_tasks', {
    description: 'List tasks sent by or assigned to the authenticated ChatGPT identity.',
    inputSchema: { status: z.enum(['open', 'done']).optional() },
  }, proxyTool(remoteClient, 'list_tasks'));

  const stdioTransport = new StdioServerTransport();
  try {
    await server.connect(stdioTransport);
  } catch {
    console.error('thunderstone-chatgpt-stdio-adapter: unable to start stdio MCP transport');
    process.exitCode = 78;
    await remoteClient.close().catch(() => {});
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : '';
  const safePrefixes = [
    'invalid bridge endpoint URL',
    'bridge endpoint must be',
    'refusing plain HTTP',
    'ChatGPT bridge credential file is missing',
    'ChatGPT credential path must be',
    'ChatGPT credential file permissions must be',
    'ChatGPT bridge credential is malformed',
  ];
  const safe = safePrefixes.some(prefix => message.startsWith(prefix));
  console.error(`thunderstone-chatgpt-stdio-adapter: ${safe ? message : 'startup failed; inspect configuration and bridge health'}`);
  process.exitCode = 78;
});
