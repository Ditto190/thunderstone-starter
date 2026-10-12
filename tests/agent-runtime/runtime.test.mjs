import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  acceptTask,
  buildPrompt,
  initTask,
  isLeaseStale,
  leaseTask,
  loadConfig,
  loadTaskState,
  submitReceipt,
  validateTask,
} from "../../scripts/agent-runtime/lib/coordinator.mjs";
import {
  compilePrompt,
  materializeInput,
  resolveSafePath,
  sha256File,
  stablePrefixHash,
} from "../../scripts/agent-runtime/lib/core.mjs";

const rootDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");

function tempRoot() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ts-runtime-"));
  fs.cpSync(path.join(rootDir, "config"), path.join(dir, "config"), { recursive: true });
  fs.mkdirSync(path.join(dir, ".state/agent-runtime"), { recursive: true });
  return dir;
}

test("stable prefix hash is deterministic", () => {
  const a = stablePrefixHash({ taskId: "A", title: "t", inputs: "x" });
  const b = stablePrefixHash({ title: "t", taskId: "A", inputs: "x" });
  assert.equal(a, b);
});

test("compilePrompt enforces byte budget", () => {
  const big = "x".repeat(200);
  const { bytes } = compilePrompt("{{inputs}}", { inputs: big }, 50);
  assert.ok(bytes <= 50);
});

test("init and lease transition queued to leased", () => {
  const dir = tempRoot();
  const taskPath = path.join(rootDir, "examples/agent-runtime/task.json");
  const state = initTask(dir, taskPath);
  assert.equal(state.status, "queued");
  const leased = leaseTask(dir, "TS-DEMO-001", "cursor-hammer", 1_700_000_000_000);
  assert.equal(leased.status, "leased");
  assert.ok(leased.lease.attemptId.includes("TS-DEMO-001"));
});

test("materializeInput reads line selectors", () => {
  const dir = tempRoot();
  fs.mkdirSync(path.join(dir, "examples/agent-runtime"), { recursive: true });
  fs.writeFileSync(
    path.join(dir, "examples/agent-runtime/input.txt"),
    "one\ntwo\nthree\n",
    "utf8",
  );
  const text = materializeInput(dir, {
    path: "examples/agent-runtime/input.txt",
    selector: { kind: "lines", start: 1, end: 2 },
  });
  assert.match(text, /one/);
  assert.match(text, /two/);
  assert.doesNotMatch(text, /three/);
});

test("resolveSafePath blocks symlink escape", () => {
  const dir = tempRoot();
  const outside = path.join(os.tmpdir(), `ts-out-${Date.now()}`);
  fs.writeFileSync(outside, "secret", "utf8");
  const link = path.join(dir, "escape-link");
  fs.symlinkSync(outside, link);
  assert.throws(() => resolveSafePath(dir, "escape-link"), /outside repository root/);
  fs.unlinkSync(outside);
});

test("stale attempt rejected on submit", () => {
  const dir = tempRoot();
  initTask(dir, path.join(rootDir, "examples/agent-runtime/task.json"));
  leaseTask(dir, "TS-DEMO-001", "cursor-hammer");
  const receiptPath = path.join(dir, "receipt.json");
  fs.writeFileSync(
    receiptPath,
    JSON.stringify({
      receiptId: "r1",
      taskId: "TS-DEMO-001",
      attemptId: "wrong-attempt",
      worker: "cursor-hammer",
      outputs: [],
    }),
    "utf8",
  );
  assert.throws(() => submitReceipt(dir, receiptPath), /stale attempt/);
});

test("duplicate receipt is idempotent", () => {
  const dir = tempRoot();
  initTask(dir, path.join(rootDir, "examples/agent-runtime/task.json"));
  leaseTask(dir, "TS-DEMO-001", "cursor-hammer");
  const outDir = path.join(dir, "examples/agent-runtime/out");
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, "report.md");
  fs.writeFileSync(outFile, "done", "utf8");
  const hash = sha256File(outFile);
  const config = loadConfig(dir);
  const state = loadTaskState(dir, config, "TS-DEMO-001");
  const receipt = {
    receiptId: "dup",
    taskId: "TS-DEMO-001",
    attemptId: state.lease.attemptId,
    worker: "cursor-hammer",
    outputs: [{ path: "examples/agent-runtime/out/report.md", sha256: hash }],
  };
  const receiptPath = path.join(dir, "receipt.json");
  fs.writeFileSync(receiptPath, JSON.stringify(receipt), "utf8");
  submitReceipt(dir, receiptPath);
  const again = submitReceipt(dir, receiptPath);
  assert.equal(again.idempotent, true);
});

test("failed gate blocks validation", () => {
  const dir = tempRoot();
  const task = {
    taskId: "TS-GATE-FAIL",
    workerPool: ["cursor-hammer"],
    routing: "pinned",
    pinnedWorker: "cursor-hammer",
    outputs: [],
    gates: [{ kind: "command", argv: ["node", "-e", "process.exit(2)"], timeoutMs: 5000 }],
    promptTemplate: "prompts/agent-runtime/worker.md",
  };
  const taskPath = path.join(dir, "task.json");
  fs.writeFileSync(taskPath, JSON.stringify(task), "utf8");
  fs.cpSync(path.join(rootDir, "prompts"), path.join(dir, "prompts"), { recursive: true });
  initTask(dir, taskPath);
  leaseTask(dir, "TS-GATE-FAIL", "cursor-hammer");
  const config = loadConfig(dir);
  const st = loadTaskState(dir, config, "TS-GATE-FAIL");
  const receiptPath = path.join(dir, "receipt.json");
  fs.writeFileSync(
    receiptPath,
    JSON.stringify({
      receiptId: "g1",
      taskId: "TS-GATE-FAIL",
      attemptId: st.lease.attemptId,
      worker: "cursor-hammer",
      outputs: [],
    }),
    "utf8",
  );
  submitReceipt(dir, receiptPath);
  const validated = validateTask(dir, "TS-GATE-FAIL");
  assert.equal(validated.status, "blocked");
});

test("happy path through accepted", () => {
  const dir = tempRoot();
  fs.cpSync(path.join(rootDir, "examples"), path.join(dir, "examples"), { recursive: true });
  fs.cpSync(path.join(rootDir, "prompts"), path.join(dir, "prompts"), { recursive: true });
  initTask(dir, path.join(dir, "examples/agent-runtime/task.json"));
  const leased = leaseTask(dir, "TS-DEMO-001", "cursor-hammer");
  const outDir = path.join(dir, "examples/agent-runtime/out");
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, "report.md");
  fs.writeFileSync(outFile, "report", "utf8");
  const receiptPath = path.join(dir, "receipt.json");
  fs.writeFileSync(
    receiptPath,
    JSON.stringify({
      receiptId: "ok",
      taskId: "TS-DEMO-001",
      attemptId: leased.lease.attemptId,
      worker: "cursor-hammer",
      outputs: [
        { path: "examples/agent-runtime/out/report.md", sha256: sha256File(outFile) },
      ],
    }),
    "utf8",
  );
  submitReceipt(dir, receiptPath);
  validateTask(dir, "TS-DEMO-001");
  const accepted = acceptTask(dir, "TS-DEMO-001");
  assert.equal(accepted.status, "accepted");
});

test("lease expiry detected", () => {
  const dir = tempRoot();
  initTask(dir, path.join(rootDir, "examples/agent-runtime/task.json"));
  const leased = leaseTask(dir, "TS-DEMO-001", "cursor-hammer", 1_000);
  assert.ok(isLeaseStale(leased, leased.lease.expiresAt + 1));
});

test("buildPrompt includes compiled prefix", () => {
  const dir = tempRoot();
  fs.cpSync(path.join(rootDir, "examples"), path.join(dir, "examples"), { recursive: true });
  fs.cpSync(path.join(rootDir, "prompts"), path.join(dir, "prompts"), { recursive: true });
  initTask(dir, path.join(dir, "examples/agent-runtime/task.json"));
  const config = loadConfig(dir);
  const state = loadTaskState(dir, config, "TS-DEMO-001");
  const prompt = buildPrompt(dir, state);
  assert.match(prompt.text, /runtime-prefix:/);
  assert.match(prompt.text, /TS-DEMO-001/);
});
