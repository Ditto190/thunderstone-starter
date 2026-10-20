import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const script = fileURLToPath(new URL("../scripts/smoke-live.mjs", import.meta.url));

function run(args, env) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [script, ...args], {
      env: { ...env, PATH: process.env.PATH },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (c) => {
      stdout += c;
    });
    child.stderr.on("data", (c) => {
      stderr += c;
    });
    child.on("close", (code) => resolve({ code, stdout, stderr }));
  });
}

test("smoke-live exits non-zero without --confirm and does not dial the network", async () => {
  const closed = "http://127.0.0.1:9";
  const { code, stdout, stderr } = await run([], {
    CURSOR_API_KEY: `crsr_${"b".repeat(32)}`,
    CURSOR_API_BASE_URL: closed,
  });
  assert.notEqual(code, 0);
  assert.match(stderr, /--confirm is required/);
  assert.equal(stdout, "");
  assert.ok(!/ECONNREFUSED|fetch failed|ENOTFOUND/i.test(stderr));
});

test("smoke-live with --confirm but no key still makes no request", async () => {
  const { code, stderr } = await run(["--confirm"], {
    CURSOR_API_BASE_URL: "http://127.0.0.1:9",
  });
  assert.notEqual(code, 0);
  assert.match(stderr, /CURSOR_API_KEY is not set/);
});
