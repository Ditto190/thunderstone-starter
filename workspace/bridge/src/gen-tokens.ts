/**
 * Generate per-agent bearer tokens.
 * Writes SHA-256 hashes to tokens.json (0600).
 * Writes plaintext once to tokens/<agent>.token (0600) for DT retrieval.
 * Never prints plaintext to stdout.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import { AGENTS, PLAINTEXT_DIR, TOKEN_DIR, TOKENS_FILE } from './config.js';

function hash(t: string): string {
  return crypto.createHash('sha256').update(t, 'utf8').digest('hex');
}

const force = process.argv.includes('--force');
if (!force && (fs.existsSync(TOKENS_FILE) || fs.existsSync(PLAINTEXT_DIR))) {
  console.error('refusing to overwrite existing bridge credentials; pass --force to rotate');
  process.exit(1);
}

fs.mkdirSync(TOKEN_DIR, { recursive: true, mode: 0o700 });
fs.mkdirSync(PLAINTEXT_DIR, { recursive: true, mode: 0o700 });

const store: Record<string, { hash: string; generated_at: string }> = {};
const now = new Date().toISOString();

for (const agent of AGENTS) {
  const token = crypto.randomBytes(32).toString('base64url');
  store[agent] = { hash: hash(token), generated_at: now };
  const plainPath = `${PLAINTEXT_DIR}/${agent}.token`;
  fs.writeFileSync(plainPath, token + '\n', { mode: 0o600 });
  fs.chmodSync(plainPath, 0o600);
}

fs.writeFileSync(TOKENS_FILE, JSON.stringify(store, null, 2) + '\n', { mode: 0o600 });
fs.chmodSync(TOKENS_FILE, 0o600);

console.log(`tokens generated for ${AGENTS.length} agents`);
console.log(`hashes: ${TOKENS_FILE}`);
console.log(`plaintext dir: ${PLAINTEXT_DIR} (0600 per file; not printed)`);
