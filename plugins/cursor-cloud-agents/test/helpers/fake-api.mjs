// Local fake of the Cursor Cloud Agents REST API (node:http only). No network beyond loopback.
import { createServer } from "node:http";

// Built at runtime so no key-shaped literal sits in source control.
export const FAKE_KEY = `crsr_${"a1b2c3d4".repeat(5)}`;

export async function startFakeApi(routes = {}) {
  const requests = [];
  const table = new Map(Object.entries(routes));
  const server = createServer((req, res) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", async () => {
      const url = new URL(req.url, "http://127.0.0.1");
      const raw = Buffer.concat(chunks).toString("utf8");
      let body;
      try {
        body = raw ? JSON.parse(raw) : undefined;
      } catch {
        body = raw;
      }
      const entry = { method: req.method, path: url.pathname, query: Object.fromEntries(url.searchParams), headers: req.headers, body };
      requests.push(entry);
      const handler = table.get(`${req.method} ${url.pathname}`);
      const out = handler ? await (typeof handler === "function" ? handler(entry) : handler) : { status: 404, body: { error: "Not Found", message: `no route ${req.method} ${url.pathname}` } };
      if (out.delayMs) await new Promise((r) => setTimeout(r, out.delayMs));
      res.writeHead(out.status ?? 200, { "content-type": "application/json", ...(out.headers ?? {}) });
      if (out.bodyDelayMs) await new Promise((r) => setTimeout(r, out.bodyDelayMs));
      res.end(out.raw ?? (out.body === undefined ? "" : JSON.stringify(out.body)));
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  return {
    baseUrl: `http://127.0.0.1:${port}`,
    requests,
    route: (key, handler) => table.set(key, handler),
    close: () => new Promise((resolve) => { server.closeAllConnections?.(); server.close(resolve); }),
  };
}

export const AGENT_ID = "bc-00000000-0000-0000-0000-000000000001";
export const RUN_ID = "run-00000000-0000-0000-0000-000000000001";
export const RUN_ID_2 = "run-00000000-0000-0000-0000-000000000002";

export const agentFixture = (over = {}) => ({
  id: AGENT_ID,
  name: "Add README",
  status: "ACTIVE",
  env: { type: "cloud" },
  repos: [{ url: "https://github.com/example-org/example-repo", startingRef: "main" }],
  workOnCurrentBranch: false,
  autoCreatePR: false,
  url: `https://cursor.com/agents/${AGENT_ID}`,
  createdAt: "2026-10-10T00:00:00.000Z",
  updatedAt: "2026-10-10T00:00:00.000Z",
  latestRunId: RUN_ID,
  ...over,
});

export const runFixture = (over = {}) => ({
  id: RUN_ID,
  agentId: AGENT_ID,
  status: "RUNNING",
  createdAt: "2026-10-10T00:00:00.000Z",
  updatedAt: "2026-10-10T00:01:00.000Z",
  ...over,
});
