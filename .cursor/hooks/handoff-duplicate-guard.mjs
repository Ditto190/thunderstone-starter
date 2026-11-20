#!/usr/bin/env node
/** Log duplicate subagent launches for the same handoff and agent type. */
import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";

const hooksDir = dirname(fileURLToPath(import.meta.url));
const root = join(hooksDir, "../..");
const stateDir = join(root, ".cursor/hooks/state");
const launches = join(stateDir, "recent-launches.jsonl");
const metrics = join(stateDir, "collection-metrics.jsonl");
const lockPath = join(stateDir, "launches.lock.d");

function readStdin() {
  return new Promise((resolve) => {
    const chunks = [];
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (c) => chunks.push(c));
    process.stdin.on("end", () => resolve(chunks.join("")));
    process.stdin.on("error", () => resolve(""));
    setTimeout(() => resolve(chunks.join("")), 2000);
  });
}

async function acquireLock(timeoutMs = 2000) {
  mkdirSync(stateDir, { recursive: true });
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      mkdirSync(lockPath);
      return true;
    } catch {
      await delay(50);
    }
  }
  return false;
}

function releaseLock() {
  try {
    rmSync(lockPath, { recursive: true, force: true });
  } catch {
    /* ignore */
  }
}

function launchKeySeen(key) {
  if (!existsSync(launches)) return false;
  return readFileSync(launches, "utf8")
    .split("\n")
    .filter(Boolean)
    .some((line) => {
      try {
        return JSON.parse(line).key === key;
      } catch {
        return false;
      }
    });
}

function allow() {
  process.stdout.write('{"permission":"allow"}\n');
  process.exit(0);
}

const raw = await readStdin();
let input = {};
try {
  input = raw.trim() ? JSON.parse(raw) : {};
} catch {
  input = {};
}

const subagentType = input.subagent_type ?? "unknown";
const taskId = input.handoff_id ?? input.task_id ?? "";
if (!taskId) allow();

const key = `${taskId}:${subagentType}`;
const ts = Date.now();
const locked = await acquireLock();
try {
  if (launchKeySeen(key)) {
    appendFileSync(
      metrics,
      `${JSON.stringify({
        ts_ms: ts,
        event: "duplicate_launch",
        launch_key: key,
      })}\n`,
      "utf8",
    );
  }
  appendFileSync(launches, `${JSON.stringify({ ts_ms: ts, key })}\n`, "utf8");
} finally {
  if (locked) releaseLock();
}

allow();
