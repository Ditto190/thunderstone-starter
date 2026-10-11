import { createServer } from "node:http";
import { dispatch } from "./dispatch.mjs";

const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 8787);

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      if (chunks.length === 0) {
        resolve(undefined);
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch {
        reject(new Error("invalid json"));
      }
    });
    req.on("error", reject);
  });
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url || "/", "http://127.0.0.1");
  let body;
  try {
    body = req.method === "POST" ? await readBody(req) : undefined;
  } catch (error) {
    res.writeHead(400, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: error.message }));
    return;
  }
  const result = dispatch({ method: req.method || "GET", pathname: url.pathname, body });
  res.writeHead(result.status, { "content-type": "application/json" });
  res.end(JSON.stringify(result.body));
});

server.listen(port, host, () => {
  process.stdout.write(`domain-analysis listening on ${host}:${port}\n`);
});
