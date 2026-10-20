import { randomUUID } from 'node:crypto';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { createMcpExpressApp } from '@modelcontextprotocol/sdk/server/express.js';
import * as z from 'zod/v4';
import type { Request, Response, NextFunction } from 'express';
import { HOST, PORT, AGENTS, AgentId, MAX_ASK, MAX_PAYLOAD, MAX_RECEIPT } from './config.js';
import { resolveAgent } from './auth.js';
import { audit } from './audit.js';
import {
  canSee,
  createTask,
  ensureDirs,
  listTasks,
  postReceipt,
  probePathSafe,
  readTask,
} from './store.js';

ensureDirs();

function textResult(obj: unknown, isError = false) {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(obj, null, 2) }],
    isError,
  };
}

function getServer(agent: AgentId): McpServer {
  const server = new McpServer({ name: 'thunderstone-bridge', version: '1.0.0' });

  server.registerTool(
    'post_task',
    {
      description: 'Post a handoff task to another agent. Confined to handoffs/. ASK <=300 chars.',
      inputSchema: {
        to: z.enum(AGENTS).describe('Recipient agent id'),
        ask: z.string().min(1).max(MAX_ASK).describe('ASK line (<=300 chars)'),
        payload: z.string().max(MAX_PAYLOAD).optional().describe('Optional payload body (<=64KB)'),
        out: z.string().max(200).optional().describe('Expected output shape'),
        due: z.string().max(80).optional().describe('Due hint'),
        pri: z.boolean().optional().describe('Priority flag'),
      },
    },
    async (args) => {
      try {
        if (args.to === agent) {
          audit({ agent, tool: 'post_task', result: 'deny', detail: 'self' });
          return textResult({ error: 'cannot_post_to_self' }, true);
        }
        const task = createTask(agent, args);
        audit({ agent, tool: 'post_task', taskId: task.id, result: 'ok' });
        return textResult({
          id: task.id,
          from: task.from,
          to: task.to,
          ask: task.ask,
          status: task.status,
          created_at: task.created_at,
        });
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'error';
        audit({ agent, tool: 'post_task', result: 'error', detail: msg });
        return textResult({ error: msg }, true);
      }
    }
  );

  server.registerTool(
    'get_task',
    {
      description: 'Get one task by id if you are sender or recipient.',
      inputSchema: {
        id: z.string().min(1).max(64).describe('Task id'),
      },
    },
    async ({ id }) => {
      try {
        if (!probePathSafe(id)) {
          audit({ agent, tool: 'get_task', taskId: id, result: 'deny', detail: 'bad_id' });
          return textResult({ error: 'bad_id' }, true);
        }
        const task = readTask(id);
        if (!canSee(agent, task)) {
          audit({ agent, tool: 'get_task', taskId: id, result: 'deny', detail: 'isolation' });
          return textResult({ error: 'not_found' }, true);
        }
        audit({ agent, tool: 'get_task', taskId: id, result: 'ok' });
        return textResult(task);
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'error';
        audit({ agent, tool: 'get_task', taskId: id, result: 'error', detail: msg });
        return textResult({ error: msg }, true);
      }
    }
  );

  server.registerTool(
    'post_receipt',
    {
      description: 'Mark a task done with a receipt. Only the assignee may call this.',
      inputSchema: {
        id: z.string().min(1).max(64),
        summary: z.string().min(1).max(MAX_RECEIPT),
      },
    },
    async ({ id, summary }) => {
      try {
        if (!probePathSafe(id)) {
          audit({ agent, tool: 'post_receipt', taskId: id, result: 'deny', detail: 'bad_id' });
          return textResult({ error: 'bad_id' }, true);
        }
        const task = postReceipt(agent, id, summary);
        audit({ agent, tool: 'post_receipt', taskId: id, result: 'ok' });
        return textResult({ id: task.id, status: task.status, receipt: task.receipt });
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'error';
        audit({ agent, tool: 'post_receipt', taskId: id, result: 'error', detail: msg });
        return textResult({ error: msg }, true);
      }
    }
  );

  server.registerTool(
    'list_tasks',
    {
      description: 'List tasks addressed to or from you.',
      inputSchema: {
        status: z.enum(['open', 'done']).optional(),
      },
    },
    async ({ status }) => {
      try {
        const tasks = listTasks(agent, status);
        audit({ agent, tool: 'list_tasks', result: 'ok', detail: `n=${tasks.length}` });
        return textResult({
          count: tasks.length,
          tasks: tasks.map((t) => ({
            id: t.id,
            from: t.from,
            to: t.to,
            ask: t.ask,
            status: t.status,
            created_at: t.created_at,
            has_receipt: Boolean(t.receipt),
          })),
        });
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'error';
        audit({ agent, tool: 'list_tasks', result: 'error', detail: msg });
        return textResult({ error: msg }, true);
      }
    }
  );

  return server;
}

const app = createMcpExpressApp({ host: HOST, allowedHosts: ['127.0.0.1', 'localhost', 'grok-bot-vm-347906125.tail6c4b90.ts.net'] });

app.use((req: Request, res: Response, next: NextFunction) => {
  // attach agent from bearer; do not log token
  const agent = resolveAgent(req.header('authorization') ?? undefined);
  (req as Request & { bridgeAgent?: AgentId | null }).bridgeAgent = agent as AgentId | null;
  if (!agent) {
    audit({ agent: 'anonymous', tool: 'http', result: 'auth_fail', detail: `${req.method} ${req.path}`.slice(0, 80) });
    res.status(401).json({ jsonrpc: '2.0', error: { code: -32001, message: 'unauthorized' }, id: null });
    return;
  }
  next();
});

app.post('/mcp', async (req, res) => {
  const agent = (req as Request & { bridgeAgent?: AgentId | null }).bridgeAgent;
  if (!agent) {
    audit({ agent: 'anonymous', tool: 'http', result: 'auth_fail', detail: 'missing_or_bad_token' });
    res.status(401).json({
      jsonrpc: '2.0',
      error: { code: -32001, message: 'unauthorized' },
      id: null,
    });
    return;
  }
  const server = getServer(agent);
  try {
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
    res.on('close', () => {
      void transport.close();
      void server.close();
    });
  } catch (error) {
    const raw = error instanceof Error ? error.message : 'unknown';
    console.error('mcp_error', raw.replace(/Bearer\s+\S+/gi, 'Bearer <redacted>').slice(0, 240));
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: '2.0',
        error: { code: -32603, message: 'Internal server error' },
        id: null,
      });
    }
  }
});

app.get('/mcp', (_req, res) => {
  res.status(405).json({ jsonrpc: '2.0', error: { code: -32000, message: 'Method not allowed.' }, id: null });
});
app.delete('/mcp', (_req, res) => {
  res.status(405).json({ jsonrpc: '2.0', error: { code: -32000, message: 'Method not allowed.' }, id: null });
});

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'not_found' });
});

app.listen(PORT, HOST, (error?: Error) => {
  if (error) {
    console.error('listen_failed', error.message);
    process.exit(1);
  }
  console.log(`thunderstone-bridge listening on http://${HOST}:${PORT}/mcp`);
  console.log(`agents: ${AGENTS.join(', ')}`);
  console.log(`instance: ${randomUUID().slice(0, 8)}`);
});
