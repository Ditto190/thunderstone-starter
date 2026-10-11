import { createServer } from "node:http";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { adviseStage, analyzeText, domainSnapshot } from "./analyze.mjs";

const MAX_BODY = 64 * 1024;
const root = new URL("../../", import.meta.url);

const routes = new Map([
  ["GET /health", () => ({ status: 200, body: { ok: true, service: "analysis" } })],
  ["GET /v1/domain", () => ({ status: 200, body: domainSnapshot() })],
  ["POST /v1/analyze", (payload) => ({
    status: 200,
    body: analyzeText(String(payload.text ?? ""), { exists: scriptExists }),
  })],
  ["POST /v1/stage", (payload) => ({
    status: 200,
    body: adviseStage(payload.signals ?? {}),
  })],
]);

export function scriptExists(rel) {
  if (typeof rel !== "string" || rel.includes("..") || rel.startsWith("/")) return false;
  return existsSync(new URL(rel, root));
}

export function startServer(port = 0) {
  const server = createServer((req, res) => {
    handle(req, res).catch(() => send(res, 500, { error: "internal" }));
  });
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

async function handle(req, res) {
  try {
    const url = new URL(req.url ?? "/", "http://127.0.0.1");
    const route = routes.get(`${req.method} ${url.pathname}`);
    if (!route) {
      send(res, 404, { error: "not_found" });
      return;
    }
    const payload = req.method === "POST" ? await readJson(req) : {};
    const result = route(payload);
    send(res, result.status, result.body);
  } catch (error) {
    const status = Number(error.status) || 500;
    if (!res.headersSent) {
      send(res, status, { error: status === 500 ? "internal" : "bad_request" });
    }
  }
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY) {
        reject(Object.assign(new Error("too_large"), { status: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      if (raw.length === 0) {
        resolve({});
        return;
      }
      try {
        const parsed = JSON.parse(raw);
        if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
          reject(Object.assign(new Error("bad_json"), { status: 400 }));
          return;
        }
        resolve(parsed);
      } catch {
        reject(Object.assign(new Error("bad_json"), { status: 400 }));
      }
    });
    req.on("error", reject);
  });
}

function send(res, status, body) {
  const encoded = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(encoded),
  });
  res.end(encoded);
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  const port = Number(process.env.ANALYSIS_PORT ?? 8787);
  startServer(port).then((server) => {
    const address = server.address();
    const bound = typeof address === "object" && address ? address.port : port;
    process.stdout.write(`analysis listening ${bound}\n`);
  });
}
