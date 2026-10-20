// Minimal REST client for the Cursor Cloud Agents v1 API (zero dependencies, Node >= 22).
// Docs: https://cursor.com/docs/cloud-agent/api/endpoints
import { redact } from "./redact.mjs";

export const DEFAULT_BASE_URL = "https://api.cursor.com";
export const DEFAULT_TIMEOUT_MS = 30000;
const MAX_ERROR_TEXT = 500;

export class ApiError extends Error {
  constructor({ status, code, message, retryAfterSeconds, details }) {
    super(message);
    this.name = "ApiError";
    this.status = status ?? null;
    this.code = code;
    this.retryAfterSeconds = retryAfterSeconds ?? null;
    this.details = details ?? null;
  }
}

function isLoopback(hostname) {
  return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1" || hostname === "[::1]";
}

export function resolveBaseUrl(env = process.env) {
  const raw = (env.CURSOR_API_BASE_URL || DEFAULT_BASE_URL).trim().replace(/\/+$/, "");
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new ApiError({ code: "invalid_base_url", message: "CURSOR_API_BASE_URL is not a valid URL." });
  }
  // The API key travels in a header, so never send it over plain http except to loopback (tests).
  if (url.protocol !== "https:" && !(url.protocol === "http:" && isLoopback(url.hostname))) {
    throw new ApiError({
      code: "invalid_base_url",
      message: "CURSOR_API_BASE_URL must use https (http is allowed only for localhost).",
    });
  }
  return raw;
}

export function resolveApiKey(env = process.env) {
  const key = (env.CURSOR_API_KEY || "").trim();
  // An unexpanded placeholder from mcp.json counts as "not set".
  if (!key || /^\$\{[^}]*\}$/.test(key)) {
    throw new ApiError({
      code: "missing_api_key",
      message: "CURSOR_API_KEY is not set for this MCP server. DT supplies it via a secret request; it is never read from chat or files.",
    });
  }
  return key;
}

export function resolveTimeoutMs(env = process.env) {
  const n = Number.parseInt(env.CURSOR_REQUEST_TIMEOUT_MS ?? "", 10);
  return Number.isFinite(n) && n >= 100 && n <= 120000 ? n : DEFAULT_TIMEOUT_MS;
}

function parseRetryAfter(headers) {
  const raw = headers.get("retry-after");
  if (!raw) return null;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

// The docs show `{code, message}` for stream errors and `{error, message}` for common REST errors;
// accept `{error:{code,message}}` too. Always return plain strings.
export function parseErrorBody(text) {
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    // not JSON
  }
  let code = null;
  let message = null;
  if (body && typeof body === "object") {
    const err = body.error;
    if (typeof body.code === "string") code = body.code;
    if (err && typeof err === "object") {
      if (typeof err.code === "string") code = code ?? err.code;
      if (typeof err.message === "string") message = err.message;
    } else if (typeof err === "string") {
      message = err;
      if (!code && /^[a-z][a-z0-9_]*$/.test(err)) code = err;
    }
    if (typeof body.message === "string") message = body.message;
  }
  if (!message && text && !body) message = text.slice(0, MAX_ERROR_TEXT);
  return { code, message, body };
}

function statusCode(status) {
  if (status === 400) return "bad_request";
  if (status === 401) return "unauthorized";
  if (status === 403) return "forbidden";
  if (status === 404) return "not_found";
  if (status === 409) return "conflict";
  if (status === 410) return "gone";
  if (status === 429) return "rate_limited";
  if (status >= 500) return "server_error";
  return "http_error";
}

export function createClient({ env = process.env, fetchImpl = globalThis.fetch } = {}) {
  async function request(method, path, { query, body } = {}) {
    const key = resolveApiKey(env);
    const base = resolveBaseUrl(env);
    const url = new URL(base + path);
    for (const [k, v] of Object.entries(query ?? {})) {
      if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, String(v));
    }
    const headers = {
      Authorization: `Bearer ${key}`,
      Accept: "application/json",
      "User-Agent": "cursor-cloud-agents-mcp/0.1.0",
    };
    const init = { method, headers, signal: AbortSignal.timeout(resolveTimeoutMs(env)), redirect: "error" };
    if (body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(body);
    }
    const transportError = (cause) => {
      const timedOut = cause?.name === "TimeoutError" || cause?.name === "AbortError";
      return new ApiError({
        code: timedOut ? "timeout" : "network_error",
        message: timedOut
          ? `Request to Cursor API timed out after ${resolveTimeoutMs(env)} ms.`
          : `Network error calling Cursor API: ${redact(String(cause?.message ?? cause), env)}`,
      });
    };
    let res;
    try {
      res = await fetchImpl(url, init);
    } catch (cause) {
      throw transportError(cause);
    }
    let text;
    try {
      text = await res.text();
    } catch (cause) {
      throw transportError(cause);
    }
    if (!res.ok) {
      const parsed = parseErrorBody(text);
      throw new ApiError({
        status: res.status,
        code: parsed.code ?? statusCode(res.status),
        message: redact(parsed.message ?? `Cursor API returned HTTP ${res.status}.`, env),
        retryAfterSeconds: parseRetryAfter(res.headers),
        details: parsed.body && typeof parsed.body === "object" ? parsed.body : null,
      });
    }
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      throw new ApiError({ status: res.status, code: "invalid_response", message: "Cursor API returned a non-JSON body." });
    }
  }

  return {
    get: (path, query) => request("GET", path, { query }),
    post: (path, body) => request("POST", path, { body }),
  };
}
