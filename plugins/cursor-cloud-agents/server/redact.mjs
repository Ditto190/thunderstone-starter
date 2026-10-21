// Secret redaction. Every string that can reach stdout, stderr or a tool result passes through here.
// The API key is read from the environment at call time and is never stored in a module-level constant.

const PATTERNS = [
  /\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{6,}/gi,
  /\b(?:crsr|key|sk|xai)[-_][A-Za-z0-9_-]{16,}/gi,
  /\bgh[pousr]_[A-Za-z0-9]{20,}/g,
  /\bgithub_pat_[A-Za-z0-9_]{20,}/g,
];

export const REDACTED = "[REDACTED]";

function secrets(env) {
  const out = [];
  const key = env.CURSOR_API_KEY;
  if (typeof key === "string" && key.length >= 4) {
    out.push(key, Buffer.from(`${key}:`).toString("base64"), Buffer.from(key).toString("base64"));
    try {
      out.push(encodeURIComponent(key));
    } catch {
      // ignore
    }
  }
  return [...new Set(out)].filter((s) => s.length >= 4);
}

export function redact(value, env = process.env) {
  let text = typeof value === "string" ? value : String(value);
  for (const secret of secrets(env)) text = text.split(secret).join(REDACTED);
  for (const pattern of PATTERNS) text = text.replace(pattern, REDACTED);
  return text;
}

export function redactDeep(value, env = process.env) {
  if (typeof value === "string") return redact(value, env);
  if (Array.isArray(value)) return value.map((v) => redactDeep(v, env));
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = redactDeep(v, env);
    return out;
  }
  return value;
}
