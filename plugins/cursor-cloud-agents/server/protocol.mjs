// JSON-RPC 2.0 / MCP message handling, independent of the transport.
// Dual-era: legacy `initialize` handshake revisions plus the stateless 2026-07-28 revision
// (per-request _meta, server/discover). Spec: https://modelcontextprotocol.io/specification
import { redact } from "./redact.mjs";
import { createToolbox } from "./tools.mjs";

export const SERVER_INFO = { name: "cursor-cloud-agents", title: "Cursor Cloud Agents", version: "0.1.0" };
export const LEGACY_VERSIONS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];
export const MODERN_VERSIONS = ["2026-07-28"];
export const SUPPORTED_VERSIONS = [...MODERN_VERSIONS, ...LEGACY_VERSIONS];
const META_VERSION = "io.modelcontextprotocol/protocolVersion";

const INSTRUCTIONS =
  "Wraps the Cursor Cloud Agents v1 REST API. launch_agent and cancel need confirm:true; launches are capped per session. " +
  "Poll get_status using nextPollSeconds; never loop faster. There is no delete tool.";

export const ERR = {
  parse: -32700,
  invalidRequest: -32600,
  methodNotFound: -32601,
  invalidParams: -32602,
  internal: -32603,
  unsupportedVersion: -32022,
};

const rpcError = (id, code, message, data) => ({ jsonrpc: "2.0", id: id ?? null, error: data === undefined ? { code, message } : { code, message, data } });
const rpcResult = (id, result) => ({ jsonrpc: "2.0", id, result });

export function createProtocol({ env = process.env, toolbox = createToolbox({ env }), log = () => {} } = {}) {
  const capabilities = { tools: { listChanged: false } };

  function modernMeta(params) {
    const v = params && typeof params === "object" ? params._meta?.[META_VERSION] : undefined;
    return typeof v === "string" ? v : undefined;
  }

  // Returns the response object for a request, or null for notifications / nothing to send.
  async function handle(message) {
    if (!message || typeof message !== "object" || Array.isArray(message) || message.jsonrpc !== "2.0") {
      return rpcError(message?.id, ERR.invalidRequest, "Invalid Request");
    }
    const { id, method, params } = message;
    const isRequest = id !== undefined && id !== null;
    if (typeof method !== "string") {
      // A response from the client (we never send requests) or garbage: ignore quietly.
      return isRequest && message.result === undefined && message.error === undefined ? rpcError(id, ERR.invalidRequest, "Invalid Request") : null;
    }
    if (!isRequest) {
      log(`notification ${method}`);
      return null; // notifications/initialized, notifications/cancelled, etc. need no reply
    }

    const requested = modernMeta(params);
    const modern = requested !== undefined;
    if (modern && !MODERN_VERSIONS.includes(requested) && method !== "initialize") {
      return rpcError(id, ERR.unsupportedVersion, "Unsupported protocol version", { supported: SUPPORTED_VERSIONS, requested });
    }
    const wrap = (result) => (modern ? { resultType: "complete", ...result } : result);

    try {
      switch (method) {
        case "initialize": {
          const asked = params?.protocolVersion;
          const protocolVersion = typeof asked === "string" && LEGACY_VERSIONS.includes(asked) ? asked : LEGACY_VERSIONS[0];
          return rpcResult(id, { protocolVersion, capabilities, serverInfo: SERVER_INFO, instructions: INSTRUCTIONS });
        }
        case "server/discover":
          return rpcResult(id, {
            resultType: "complete",
            supportedVersions: SUPPORTED_VERSIONS,
            capabilities,
            _meta: { "io.modelcontextprotocol/serverInfo": { name: SERVER_INFO.name, version: SERVER_INFO.version } },
            instructions: INSTRUCTIONS,
            ttlMs: 3600000,
            cacheScope: "public",
          });
        case "ping":
          return rpcResult(id, wrap({}));
        case "tools/list":
          return rpcResult(id, wrap({ tools: toolbox.definitions }));
        case "tools/call": {
          const name = params?.name;
          if (typeof name !== "string" || !name) return rpcError(id, ERR.invalidParams, "tools/call requires a tool name");
          const out = await toolbox.call(name, params.arguments);
          if (out.unknownTool) return rpcError(id, ERR.invalidParams, `Unknown tool: ${redact(name, env).slice(0, 80)}`);
          const text = JSON.stringify(out.data, null, 2);
          return rpcResult(id, wrap({ content: [{ type: "text", text }], structuredContent: out.data, isError: out.isError }));
        }
        default:
          return rpcError(id, ERR.methodNotFound, `Method not found: ${redact(method, env).slice(0, 80)}`);
      }
    } catch (err) {
      log(`internal error: ${redact(String(err?.message ?? err), env)}`);
      return rpcError(id, ERR.internal, "Internal error");
    }
  }

  return { handle };
}
