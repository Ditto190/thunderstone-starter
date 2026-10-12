import fs from "node:fs";
import path from "node:path";
import {
  compilePrompt,
  loadJson,
  materializeInput,
  resolveSafePath,
  runCommand,
  sha256File,
  writeJson,
} from "./core.mjs";

const TERMINAL = new Set(["accepted", "failed", "blocked"]);

export function statePath(rootDir, config, taskId) {
  return path.join(rootDir, config.stateDir, `${taskId}.json`);
}

export function loadConfig(rootDir) {
  return loadJson(path.join(rootDir, "config/agent-runtime.json"));
}

export function loadTaskState(rootDir, config, taskId) {
  const p = statePath(rootDir, config, taskId);
  if (!fs.existsSync(p)) {
    return null;
  }
  return loadJson(p);
}

export function saveTaskState(rootDir, config, state) {
  writeJson(statePath(rootDir, config, state.taskId), state);
}

export function initTask(rootDir, taskPath) {
  const config = loadConfig(rootDir);
  const descriptor = loadJson(path.resolve(taskPath));
  const taskId = descriptor.taskId;
  if (!taskId) {
    throw new Error("task descriptor requires taskId");
  }
  const existing = loadTaskState(rootDir, config, taskId);
  if (existing && !TERMINAL.has(existing.status)) {
    throw new Error(`task ${taskId} already active with status ${existing.status}`);
  }
  const state = {
    taskId,
    descriptor,
    status: "queued",
    history: [{ at: new Date().toISOString(), status: "queued" }],
    receipts: {},
    attemptSeq: 0,
  };
  saveTaskState(rootDir, config, state);
  return state;
}

function pickWorker(descriptor, config, state, requestedWorker) {
  const pool = descriptor.workerPool ?? [];
  const routing = descriptor.routing ?? "pinned";
  if (requestedWorker) {
    if (!pool.includes(requestedWorker)) {
      throw new Error(`worker ${requestedWorker} not in task pool`);
    }
    return requestedWorker;
  }
  if (routing === "pinned") {
    const pinned = descriptor.pinnedWorker ?? pool[0];
    if (!pinned) {
      throw new Error("pinned routing requires pinnedWorker or workerPool");
    }
    return pinned;
  }
  const idx = state.attemptSeq % pool.length;
  return pool[idx];
}

export function leaseTask(rootDir, taskId, workerName, now = Date.now()) {
  const config = loadConfig(rootDir);
  const state = loadTaskState(rootDir, config, taskId);
  if (!state) {
    throw new Error(`unknown task ${taskId}`);
  }
  if (state.status === "leased" && state.lease?.expiresAt > now) {
    if (workerName && state.lease.worker !== workerName) {
      throw new Error(`task leased to ${state.lease.worker}`);
    }
    return state;
  }
  if (TERMINAL.has(state.status)) {
    throw new Error(`task ${taskId} is terminal (${state.status})`);
  }
  if (!["queued", "leased"].includes(state.status)) {
    throw new Error(`cannot lease task in status ${state.status}`);
  }
  const worker = pickWorker(state.descriptor, config, state, workerName);
  const attemptId = `${taskId}-${++state.attemptSeq}`;
  const expiresAt = now + config.leaseSeconds * 1000;
  state.status = "leased";
  state.lease = { worker, attemptId, expiresAt, leasedAt: now };
  state.history.push({
    at: new Date(now).toISOString(),
    status: "leased",
    worker,
    attemptId,
  });
  saveTaskState(rootDir, config, state);
  return state;
}

export function buildPrompt(rootDir, state) {
  const config = loadConfig(rootDir);
  const descriptor = state.descriptor;
  const inputBlocks = (descriptor.inputs ?? []).map((input) => {
    const body = materializeInput(rootDir, input);
    return `### ${input.path}\n\n${body}`;
  });
  const outputs = (descriptor.outputs ?? [])
    .map((o) => `- ${o.path}${o.required ? " (required)" : ""}`)
    .join("\n");
  const templatePath = path.join(rootDir, descriptor.promptTemplate);
  const templateText = fs.readFileSync(templatePath, "utf8");
  return compilePrompt(
    templateText,
    {
      taskId: descriptor.taskId,
      title: descriptor.title ?? descriptor.taskId,
      inputs: inputBlocks.join("\n\n"),
      outputs,
    },
    config.promptByteBudget,
  );
}

export function submitReceipt(rootDir, receiptPath) {
  const config = loadConfig(rootDir);
  const receipt = loadJson(path.resolve(receiptPath));
  const state = loadTaskState(rootDir, config, receipt.taskId);
  if (!state) {
    throw new Error(`unknown task ${receipt.taskId}`);
  }
  const rid = receipt.receiptId;
  if (state.receipts[rid]) {
    return { state, receipt: state.receipts[rid], idempotent: true };
  }
  if (state.status !== "leased") {
    throw new Error(`submit requires leased status, got ${state.status}`);
  }
  if (!state.lease || receipt.attemptId !== state.lease.attemptId) {
    throw new Error("stale attempt: receipt attemptId does not match active lease");
  }
  if (receipt.worker !== state.lease.worker) {
    throw new Error("receipt worker does not match lease");
  }
  for (const out of receipt.outputs ?? []) {
    const abs = resolveSafePath(rootDir, out.path);
    if (!fs.existsSync(abs)) {
      throw new Error(`missing output artifact: ${out.path}`);
    }
    const hash = sha256File(abs);
    if (out.sha256 && out.sha256 !== hash) {
      throw new Error(`output hash mismatch for ${out.path}`);
    }
    out.sha256 = hash;
  }
  state.receipts[rid] = receipt;
  state.status = "submitted";
  state.history.push({
    at: new Date().toISOString(),
    status: "submitted",
    receiptId: rid,
  });
  saveTaskState(rootDir, config, state);
  return { state, receipt, idempotent: false };
}

export function runGates(rootDir, state) {
  const descriptor = state.descriptor;
  const results = [];
  for (const gate of descriptor.gates ?? []) {
    if (gate.kind === "command") {
      const res = runCommand(gate.argv, gate.timeoutMs ?? 60_000, rootDir);
      results.push({ gate, ...res });
      if (!res.ok) {
        return { ok: false, results };
      }
    } else {
      throw new Error(`unsupported gate kind: ${gate.kind}`);
    }
  }
  return { ok: true, results };
}

export function validateTask(rootDir, taskId) {
  const config = loadConfig(rootDir);
  const state = loadTaskState(rootDir, config, taskId);
  if (!state) {
    throw new Error(`unknown task ${taskId}`);
  }
  if (state.status !== "submitted") {
    throw new Error(`validate requires submitted status, got ${state.status}`);
  }
  const gateResult = runGates(rootDir, state);
  if (!gateResult.ok) {
    state.status = "blocked";
    state.blockedReason = "gate-failed";
    state.gateResults = gateResult.results;
    state.history.push({ at: new Date().toISOString(), status: "blocked" });
    saveTaskState(rootDir, config, state);
    return state;
  }
  for (const out of state.descriptor.outputs ?? []) {
    if (!out.required) {
      continue;
    }
    const abs = resolveSafePath(rootDir, out.path);
    if (!fs.existsSync(abs)) {
      state.status = "failed";
      state.failureReason = `missing required output ${out.path}`;
      state.history.push({ at: new Date().toISOString(), status: "failed" });
      saveTaskState(rootDir, config, state);
      return state;
    }
  }
  state.status = "validated";
  state.gateResults = gateResult.results;
  state.history.push({ at: new Date().toISOString(), status: "validated" });
  saveTaskState(rootDir, config, state);
  return state;
}

export function runAcceptance(rootDir, state, timeoutMs) {
  const checks = state.descriptor.acceptance ?? [];
  const started = Date.now();
  for (const check of checks) {
    if (Date.now() - started > timeoutMs) {
      return { ok: false, reason: "acceptance-timeout" };
    }
    if (check.kind === "file-exists") {
      const abs = resolveSafePath(rootDir, check.path);
      if (!fs.existsSync(abs)) {
        return { ok: false, reason: `missing ${check.path}` };
      }
    } else {
      return { ok: false, reason: `unsupported acceptance kind ${check.kind}` };
    }
  }
  return { ok: true };
}

export function acceptTask(rootDir, taskId) {
  const config = loadConfig(rootDir);
  const state = loadTaskState(rootDir, config, taskId);
  if (!state) {
    throw new Error(`unknown task ${taskId}`);
  }
  if (state.status !== "validated") {
    throw new Error(`accept requires validated status, got ${state.status}`);
  }
  const acceptance = runAcceptance(rootDir, state, config.acceptanceTimeoutMs);
  if (!acceptance.ok) {
    state.status = "failed";
    state.failureReason = acceptance.reason;
    state.history.push({ at: new Date().toISOString(), status: "failed" });
    saveTaskState(rootDir, config, state);
    return state;
  }
  state.status = "accepted";
  state.history.push({ at: new Date().toISOString(), status: "accepted" });
  saveTaskState(rootDir, config, state);
  return state;
}

export function isLeaseStale(state, now = Date.now()) {
  return state.status === "leased" && state.lease && state.lease.expiresAt <= now;
}
