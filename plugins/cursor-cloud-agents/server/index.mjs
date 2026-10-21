#!/usr/bin/env node
// stdio entry point. stdout carries only newline-delimited JSON-RPC; diagnostics go to stderr (redacted).
import { createInterface } from "node:readline";
import { createProtocol, ERR } from "./protocol.mjs";
import { redact } from "./redact.mjs";

const stderrLog = (line) => process.stderr.write(`[cursor-cloud-agents] ${redact(line)}\n`);
const protocol = createProtocol({ log: process.env.CURSOR_MCP_DEBUG === "1" ? stderrLog : () => {} });

let pending = 0;
let closing = false;
const maybeExit = () => {
  if (closing && pending === 0) process.exit(0);
};

function send(obj, done) {
  process.stdout.write(`${JSON.stringify(obj)}\n`, () => done?.());
}

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });
rl.on("line", (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let message;
  try {
    message = JSON.parse(trimmed);
  } catch {
    send({ jsonrpc: "2.0", id: null, error: { code: ERR.parse, message: "Parse error" } });
    return;
  }
  pending += 1;
  const finish = () => {
    pending -= 1;
    maybeExit();
  };
  protocol.handle(message).then(
    (response) => {
      if (response) send(response, finish);
      else finish();
    },
    (err) => {
      stderrLog(`unhandled: ${String(err?.message ?? err)}`);
      finish();
    },
  );
});
// Closing stdin is the graceful-shutdown signal; finish in-flight requests, then exit.
rl.on("close", () => {
  closing = true;
  maybeExit();
});
process.on("SIGTERM", () => process.exit(0));
process.on("SIGINT", () => process.exit(0));
