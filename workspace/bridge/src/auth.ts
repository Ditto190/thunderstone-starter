import crypto from 'node:crypto';
import fs from 'node:fs';
import { TOKENS_FILE } from './config.js';

type TokenStore = Record<string, { hash: string }>;

function loadStore(): TokenStore {
  try {
    if (!fs.existsSync(TOKENS_FILE)) return {};
    const parsed: unknown = JSON.parse(fs.readFileSync(TOKENS_FILE, 'utf8'));
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    return parsed as TokenStore;
  } catch {
    return {};
  }
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

const CLIENT_RE = /^[a-z0-9][a-z0-9._-]{0,63}$/;

export function resolveAgent(bearer: string | undefined): string | null {
  if (!bearer) return null;
  const m = /^Bearer\s+(\S+)$/i.exec(bearer.trim());
  if (!m) return null;
  const h = hashToken(m[1]);
  const store = loadStore();
  let found: string | null = null;
  for (const id of Object.keys(store)) {
    if (!CLIENT_RE.test(id)) continue;
    const row = store[id];
    if (row && typeof row.hash === 'string' && timingSafeEqualHex(row.hash, h) && !found) found = id;
  }
  return found;
}

export function timingSafeEqualHex(a: string, b: string): boolean {
  try {
    const ba = Buffer.from(a, 'hex');
    const bb = Buffer.from(b, 'hex');
    if (ba.length === 0 || ba.length !== bb.length) {
      const filler = Buffer.alloc(32);
      crypto.timingSafeEqual(filler, filler);
      return false;
    }
    return crypto.timingSafeEqual(ba, bb);
  } catch {
    return false;
  }
}
