#!/usr/bin/env node
/** Append agent-collection KPI events to collection-metrics.jsonl (fail-open). */
import { appendFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const hooksDir = dirname(fileURLToPath(import.meta.url));
const root = join(hooksDir, "../..");
const stateDir = join(root, ".cursor/hooks/state");
const metrics = join(stateDir, "collection-metrics.jsonl");

function readStdin() {
  return new Promise((resolve) => {
    const chunks = [];
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (c) => chunks.push(c));
    process.stdin.on("end", () => resolve(chunks.join("")));
    process.stdin.on("error", () => resolve(""));
    // Windows hooks sometimes deliver empty/hanging stdin — don't block forever.
    setTimeout(() => resolve(chunks.join("")), 2000);
  });
}

function tsMsNow() {
  return Date.now();
}

function nullIfEmpty(s) {
  return s === undefined || s === null || s === "" ? null : s;
}

const raw = await readStdin();
let input = {};
try {
  input = raw.trim() ? JSON.parse(raw) : {};
} catch {
  input = {};
}

mkdirSync(stateDir, { recursive: true });

const event = input.hook_event_name ?? "unknown";
let ts = input.timestamp_ms;
if (ts === undefined || ts === null || ts === "" || Number.isNaN(Number(ts))) {
  ts = tsMsNow();
} else {
  ts = Number(ts);
}

const line = {
  ts_ms: ts,
  event,
  subagent_type: nullIfEmpty(input.subagent_type ?? input.tool_name),
  conversation_id: nullIfEmpty(input.conversation_id ?? input.session_id),
  status: nullIfEmpty(input.status),
  failure_type: nullIfEmpty(input.failure_type),
};

appendFileSync(metrics, `${JSON.stringify(line)}\n`, "utf8");
process.exit(0);
