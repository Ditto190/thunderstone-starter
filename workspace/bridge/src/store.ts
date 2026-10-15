import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {
  AGENTS,
  AgentId,
  HANDOFFS_ROOT,
  ID_RE,
  MAX_ASK,
  MAX_DUE,
  MAX_OUT,
  MAX_PAYLOAD,
  MAX_RECEIPT,
  TASKS_DIR,
} from './config.js';

export type TaskStatus = 'open' | 'done';

export interface Task {
  id: string;
  from: AgentId;
  to: AgentId;
  ask: string;
  payload: string;
  out: string;
  due: string;
  pri: boolean;
  status: TaskStatus;
  created_at: string;
  receipt: null | { by: AgentId; at: string; summary: string };
}

function assertUnderHandoffs(resolved: string): void {
  const root = path.resolve(HANDOFFS_ROOT) + path.sep;
  const target = path.resolve(resolved);
  if (!(target + path.sep).startsWith(root) && target !== path.resolve(HANDOFFS_ROOT)) {
    throw new Error('path_escape');
  }
}

export function ensureDirs(): void {
  fs.mkdirSync(TASKS_DIR, { recursive: true, mode: 0o700 });
  assertUnderHandoffs(TASKS_DIR);
}

function taskPath(id: string): string {
  if (!ID_RE.test(id)) throw new Error('bad_id');
  const p = path.join(TASKS_DIR, `${id}.json`);
  assertUnderHandoffs(p);
  // reject traversal via id even if regex passed weird unicode
  if (path.basename(p) !== `${id}.json`) throw new Error('bad_id');
  return p;
}

function isLink(p: string): boolean {
  try { return fs.lstatSync(p).isSymbolicLink(); } catch { return false; }
}

function isAgent(x: string): x is AgentId {
  return (AGENTS as readonly string[]).includes(x);
}

export function createTask(
  from: AgentId,
  input: { to: string; ask: string; payload?: string; out?: string; due?: string; pri?: boolean }
): Task {
  if (!isAgent(input.to)) throw new Error('bad_to');
  if (typeof input.ask !== 'string' || input.ask.length === 0 || input.ask.length > MAX_ASK) {
    throw new Error('bad_ask');
  }
  const payload = input.payload ?? '';
  if (typeof payload !== 'string' || Buffer.byteLength(payload, 'utf8') > MAX_PAYLOAD) {
    throw new Error('bad_payload');
  }
  const out = input.out ?? 'reply<=5 lines';
  const due = input.due ?? 'next-turn';
  if (out.length > MAX_OUT || due.length > MAX_DUE) throw new Error('bad_meta');

  const id = `t${Date.now().toString(36)}${crypto.randomBytes(4).toString('hex')}`;
  const task: Task = {
    id,
    from,
    to: input.to,
    ask: input.ask,
    payload,
    out,
    due,
    pri: Boolean(input.pri),
    status: 'open',
    created_at: new Date().toISOString(),
    receipt: null,
  };
  ensureDirs();
  const p = taskPath(id);
  fs.writeFileSync(p, JSON.stringify(task, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
  return task;
}

function assertRealUnder(p: string): void {
  const st = fs.lstatSync(p);
  if (st.isSymbolicLink() || !st.isFile()) throw new Error('path_escape');
  const realRoot = fs.realpathSync(TASKS_DIR) + path.sep;
  if (!fs.realpathSync(p).startsWith(realRoot)) throw new Error('path_escape');
}

export function readTask(id: string): Task {
  const p = taskPath(id);
  if (!fs.existsSync(p) && !isLink(p)) throw new Error('not_found');
  assertRealUnder(p);
  return JSON.parse(fs.readFileSync(p, 'utf8')) as Task;
}

export function canSee(agent: AgentId, task: Task): boolean {
  return task.from === agent || task.to === agent;
}

export function listTasks(agent: AgentId, status?: TaskStatus): Task[] {
  ensureDirs();
  const files = fs.readdirSync(TASKS_DIR).filter((f) => f.endsWith('.json'));
  const out: Task[] = [];
  for (const f of files) {
    const id = f.slice(0, -5);
    if (!ID_RE.test(id)) continue;
    try {
      const t = readTask(id);
      if (!canSee(agent, t)) continue;
      if (status && t.status !== status) continue;
      out.push(t);
    } catch {
      /* skip corrupt */
    }
  }
  out.sort((a, b) => {
    if (a.created_at === b.created_at) {
      if (a.id === b.id) return 0;
      return a.id < b.id ? 1 : -1;
    }
    return a.created_at < b.created_at ? 1 : -1;
  });
  return out;
}

export function postReceipt(agent: AgentId, id: string, summary: string): Task {
  if (typeof summary !== 'string' || summary.length === 0 || Buffer.byteLength(summary, 'utf8') > MAX_RECEIPT) {
    throw new Error('bad_receipt');
  }
  const task = readTask(id);
  if (task.to !== agent) throw new Error('not_assignee');
  if (task.status === 'done') throw new Error('already_done');
  task.status = 'done';
  task.receipt = { by: agent, at: new Date().toISOString(), summary };
  const p = taskPath(id);
  assertRealUnder(p);
  fs.writeFileSync(p, JSON.stringify(task, null, 2) + '\n', { mode: 0o600 });
  return task;
}

/** Reject obvious traversal probes without touching fs outside root */
export function probePathSafe(candidate: string): boolean {
  try {
    if (candidate.includes('..') || candidate.includes('/') || candidate.includes('\\')) return false;
    if (!ID_RE.test(candidate)) return false;
    taskPath(candidate);
    return true;
  } catch {
    return false;
  }
}
