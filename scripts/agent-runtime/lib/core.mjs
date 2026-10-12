import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

export function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

export function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

export function sha256Buffer(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

export function sha256File(filePath) {
  return sha256Buffer(fs.readFileSync(filePath));
}

/** Resolve a repo-relative path; reject escapes via symlinks outside root. */
export function resolveSafePath(rootDir, relPath) {
  const root = path.resolve(rootDir);
  const target = path.resolve(root, relPath);
  const rel = path.relative(root, target);
  if (rel.startsWith("..") || path.isAbsolute(rel)) {
    throw new Error(`path escapes repository root: ${relPath}`);
  }
  if (!fs.existsSync(target)) {
    return target;
  }
  const real = fs.realpathSync(target);
  const realRel = path.relative(root, real);
  if (realRel.startsWith("..") || path.isAbsolute(realRel)) {
    throw new Error(`path resolves outside repository root: ${relPath}`);
  }
  return real;
}

export function readLinesSlice(filePath, start, end) {
  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  const slice = lines.slice(start - 1, end);
  return slice.join("\n");
}

export function readJsonPointer(filePath, pointer) {
  const doc = JSON.parse(fs.readFileSync(filePath, "utf8"));
  if (!pointer || pointer === "/") {
    return JSON.stringify(doc, null, 2);
  }
  const parts = pointer.split("/").filter(Boolean);
  let cur = doc;
  for (const part of parts) {
    const key = part.replace(/~1/g, "/").replace(/~0/g, "~");
    if (cur == null || typeof cur !== "object" || !(key in cur)) {
      throw new Error(`json pointer not found: ${pointer}`);
    }
    cur = cur[key];
  }
  return typeof cur === "string" ? cur : JSON.stringify(cur, null, 2);
}

export function materializeInput(rootDir, input) {
  const abs = resolveSafePath(rootDir, input.path);
  if (!fs.existsSync(abs)) {
    throw new Error(`missing input artifact: ${input.path}`);
  }
  const sel = input.selector;
  if (!sel) {
    return fs.readFileSync(abs, "utf8");
  }
  if (typeof sel === "string") {
    if (sel.startsWith("lines:")) {
      const [, range] = sel.split(":");
      const [a, b] = range.split("-").map((n) => Number.parseInt(n, 10));
      return readLinesSlice(abs, a, b);
    }
    if (sel.startsWith("json:")) {
      return readJsonPointer(abs, sel.slice(5));
    }
  }
  if (sel.kind === "lines") {
    return readLinesSlice(abs, sel.start, sel.end);
  }
  if (sel.kind === "json-pointer") {
    return readJsonPointer(abs, sel.pointer);
  }
  throw new Error(`unsupported selector for ${input.path}`);
}

export function stablePrefixHash(parts) {
  const keys = Object.keys(parts).sort();
  const canonical = keys.map((k) => [k, parts[k]]);
  return sha256Buffer(JSON.stringify(canonical)).slice(0, 16);
}

export function compilePrompt(templateText, vars, byteBudget) {
  let out = templateText;
  for (const [key, value] of Object.entries(vars)) {
    out = out.replaceAll(`{{${key}}}`, String(value));
  }
  const prefixHash = stablePrefixHash({
    taskId: vars.taskId ?? "",
    title: vars.title ?? "",
    inputs: vars.inputs ?? "",
  });
  const header = `<!-- runtime-prefix:${prefixHash} -->\n`;
  let body = `${header}${out}`;
  const buf = Buffer.from(body, "utf8");
  if (buf.length > byteBudget) {
    body = buf.subarray(0, byteBudget).toString("utf8");
  }
  return { text: body, prefixHash, bytes: Buffer.byteLength(body, "utf8") };
}

export function runCommand(argv, timeoutMs, cwd) {
  const res = spawnSync(argv[0], argv.slice(1), {
    cwd,
    encoding: "utf8",
    timeout: timeoutMs,
  });
  return {
    ok: res.status === 0,
    status: res.status ?? 1,
    stdout: res.stdout ?? "",
    stderr: res.stderr ?? "",
    signal: res.signal,
  };
}
