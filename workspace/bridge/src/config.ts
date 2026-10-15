import path from 'node:path';
import os from 'node:os';

export const HOST = '127.0.0.1';
export const PORT = Number(process.env.BRIDGE_PORT || 3847);
const thunderstoneRoot = process.env.THUNDERSTONE_ROOT ?? path.join(path.sep, 'workspace', 'thunderstone');
export const HANDOFFS_ROOT = path.join(thunderstoneRoot, 'handoffs');
export const TASKS_DIR = path.join(HANDOFFS_ROOT, 'tasks');
export const AUDIT_LOG = path.join(thunderstoneRoot, 'state', 'bridge-audit.log');
export const TOKEN_DIR = path.join(os.homedir(), '.config', 'thunderstone-bridge');
export const TOKENS_FILE = path.join(TOKEN_DIR, 'tokens.json');
export const PLAINTEXT_DIR = path.join(TOKEN_DIR, 'tokens');

export const AGENTS = ['grok-bot', 'cursor', 'chatgpt', 'claude', 'perplexity'] as const;
export type AgentId = (typeof AGENTS)[number];

export const ID_RE = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$/;
export const MAX_ASK = 300;
export const MAX_PAYLOAD = 64 * 1024;
export const MAX_RECEIPT = 2 * 1024;
export const MAX_OUT = 200;
export const MAX_DUE = 80;
