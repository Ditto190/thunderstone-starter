#!/usr/bin/env node
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  acceptTask,
  buildPrompt,
  initTask,
  leaseTask,
  loadTaskState,
  loadConfig,
  submitReceipt,
  validateTask,
} from "./agent-runtime/lib/coordinator.mjs";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        args[key] = true;
      } else {
        args[key] = next;
        i += 1;
      }
    } else {
      args._.push(a);
    }
  }
  return args;
}

function printJson(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);
  if (!command || command === "help") {
    console.log(`Usage:
  node scripts/agent-runtime.mjs init --task <task.json>
  node scripts/agent-runtime.mjs lease --task-id <id> --worker <name>
  node scripts/agent-runtime.mjs prompt --task-id <id>
  node scripts/agent-runtime.mjs submit --receipt <receipt.json>
  node scripts/agent-runtime.mjs validate --task-id <id>
  node scripts/agent-runtime.mjs accept --task-id <id>
  node scripts/agent-runtime.mjs status --task-id <id>`);
    process.exit(command ? 0 : 1);
  }

  switch (command) {
    case "init": {
      const task = args.task;
      if (!task) {
        throw new Error("init requires --task");
      }
      const state = initTask(rootDir, task);
      printJson({ taskId: state.taskId, status: state.status });
      break;
    }
    case "lease": {
      const taskId = args["task-id"];
      const worker = args.worker;
      if (!taskId || !worker) {
        throw new Error("lease requires --task-id and --worker");
      }
      const state = leaseTask(rootDir, taskId, worker);
      const prompt = buildPrompt(rootDir, state);
      printJson({
        taskId: state.taskId,
        status: state.status,
        worker: state.lease.worker,
        attemptId: state.lease.attemptId,
        expiresAt: state.lease.expiresAt,
        promptPrefix: prompt.prefixHash,
        promptBytes: prompt.bytes,
      });
      break;
    }
    case "prompt": {
      const taskId = args["task-id"];
      if (!taskId) {
        throw new Error("prompt requires --task-id");
      }
      const config = loadConfig(rootDir);
      const state = loadTaskState(rootDir, config, taskId);
      if (!state) {
        throw new Error(`unknown task ${taskId}`);
      }
      const prompt = buildPrompt(rootDir, state);
      process.stdout.write(`${prompt.text}\n`);
      break;
    }
    case "submit": {
      const receipt = args.receipt;
      if (!receipt) {
        throw new Error("submit requires --receipt");
      }
      const result = submitReceipt(rootDir, receipt);
      printJson({
        taskId: result.state.taskId,
        status: result.state.status,
        receiptId: result.receipt.receiptId,
        idempotent: result.idempotent,
      });
      break;
    }
    case "validate": {
      const taskId = args["task-id"];
      if (!taskId) {
        throw new Error("validate requires --task-id");
      }
      const state = validateTask(rootDir, taskId);
      printJson({ taskId: state.taskId, status: state.status });
      break;
    }
    case "accept": {
      const taskId = args["task-id"];
      if (!taskId) {
        throw new Error("accept requires --task-id");
      }
      const state = acceptTask(rootDir, taskId);
      printJson({ taskId: state.taskId, status: state.status });
      break;
    }
    case "status": {
      const taskId = args["task-id"];
      if (!taskId) {
        throw new Error("status requires --task-id");
      }
      const config = loadConfig(rootDir);
      const state = loadTaskState(rootDir, config, taskId);
      if (!state) {
        throw new Error(`unknown task ${taskId}`);
      }
      printJson(state);
      break;
    }
    default:
      throw new Error(`unknown command: ${command}`);
  }
}

main().catch((err) => {
  console.error(err.message || String(err));
  process.exit(1);
});
