async function readBody(req) {
  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return req.body;
  }
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (chunks.length === 0) return undefined;
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

async function send(req, res, pathname) {
  const { dispatch } = await import("../services/domain-analysis/dispatch.mjs");
  let body;
  try {
    body = req.method === "POST" ? await readBody(req) : undefined;
  } catch {
    res.statusCode = 400;
    res.setHeader("content-type", "application/json");
    res.end(JSON.stringify({ error: "invalid json" }));
    return;
  }
  const result = dispatch({ method: req.method, pathname, body });
  res.statusCode = result.status;
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify(result.body));
}

module.exports = { send };
