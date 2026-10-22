import fs from 'node:fs';
import path from 'node:path';
import { AUDIT_LOG } from './config.js';

export function audit(entry: {
  agent: string;
  tool: string;
  taskId?: string;
  result: 'ok' | 'deny' | 'error' | 'auth_fail';
  detail?: string;
}): void {
  const line = JSON.stringify({
    ts: new Date().toISOString(),
    agent: entry.agent,
    tool: entry.tool,
    taskId: entry.taskId ?? null,
    result: entry.result,
    detail: entry.detail ?? null,
  });
  fs.mkdirSync(path.dirname(AUDIT_LOG), { recursive: true });
  fs.appendFileSync(AUDIT_LOG, line + '\n', { mode: 0o600 });
}
