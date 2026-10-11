/**
 * Clan work items. State is the files under workspace/items/<ID>/.
 * Public surface is the CLI. scripts/run-task.sh and scripts/export-drive.sh
 * are the only supported callers of run and export.
 */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  CONTRACT,
  artifacts,
  deniedTools,
  envNeeded,
  findRole,
  grantedTools,
  labelLines,
  signalLabels,
  changelogSections,
  validateContract,
} from "./clan-contract.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ITEM_ID = /^[A-Z][A-Z0-9]*-\d{3,}$/;
const LAYOUT = {
  brief: "brief.md",
  runs: "runs.jsonl",
  report: "report.md",
  exportDir: "export",
  receipts: "receipts.jsonl",
};
const CLI_MARKER = "thunderstone-deny-only";

function itemDir(id) {
  return join(ROOT, "workspace", "items", id);
}

function fail(message) {
  console.error(`clan: ${message}`);
  return 1;
}

function parseId(raw) {
  return ITEM_ID.test(raw) ? raw : null;
}

function readText(path) {
  return existsSync(path) ? readFileSync(path, "utf8") : null;
}

function walkFiles(dir, prefix = "") {
  if (!existsSync(dir)) return [];
  const found = [];
  for (const name of readdirSync(dir)) {
    const rel = prefix ? `${prefix}/${name}` : name;
    const abs = join(dir, name);
    const stat = lstatSync(abs);
    if (stat.isSymbolicLink()) found.push({ path: rel, type: "symlink", sha256: null });
    else if (stat.isDirectory()) found.push(...walkFiles(abs, rel));
    else if (stat.isFile()) found.push({ path: rel, type: "file", sha256: createHash("sha256").update(readFileSync(abs)).digest("hex") });
    else found.push({ path: rel, type: "other", sha256: null });
  }
  return found.sort((a, b) => a.path.localeCompare(b.path));
}

function denyName(path, patterns) {
  return patterns.find((pattern) => {
    const expression = `^${pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*\*/g, ".*").replace(/\*/g, "[^/]*")}$`;
    return new RegExp(expression).test(path) || new RegExp(expression).test(path.split("/").pop());
  });
}

function bootId() {
  const path = "/proc/sys/kernel/random/boot_id";
  return existsSync(path) ? readFileSync(path, "utf8").trim() : "unknown";
}

function isLive(pid, stampedBoot) {
  if (stampedBoot !== "unknown" && stampedBoot !== bootId()) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function parseRuns(lines) {
  const attempts = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trim()) continue;
    let event;
    try {
      event = JSON.parse(line);
    } catch {
      return { error: `bad run log line ${index + 1}` };
    }
    if (event.v !== 1 || !Number.isInteger(event.n)) return { error: `bad run log line ${index + 1}` };
    if (event.event === "start") {
      attempts.push({
        n: event.n,
        executor: event.executor,
        roleId: event.role,
        startedAt: event.at,
        host: event.pid ? { pid: event.pid, bootId: event.boot } : null,
        ended: null,
      });
    } else if (event.event === "end") {
      const open = attempts.find((attempt) => attempt.n === event.n && attempt.ended === null);
      if (!open) return { error: `bad run log line ${index + 1}` };
      open.ended = { at: event.at, exit: event.exit };
    } else return { error: `bad run log line ${index + 1}` };
  }
  return { attempts };
}

function digestOf(entries) {
  const body = entries.map((entry) => `${entry.path}\0${entry.sha256}\n`).join("");
  return createHash("sha256").update(body).digest("hex");
}

function loadItem(id) {
  const dir = itemDir(id);
  const briefText = readText(join(dir, LAYOUT.brief));
  const problems = [];
  if (briefText === null) return { ok: false, id, problems: ["no brief"] };
  const roleId = briefText.split("\n", 1)[0].startsWith("role: ") ? briefText.split("\n", 1)[0].slice(6).trim() : "";
  const role = findRole(CONTRACT, roleId);
  if (!role) problems.push(`unknown role ${roleId || "(missing)"}`);
  else if (role.kind === "instruction_only") problems.push(`${roleId} is instruction-only`);
  const runText = readText(join(dir, LAYOUT.runs)) ?? "";
  const parsed = parseRuns(runText.split("\n"));
  if (parsed.error) problems.push(parsed.error);
  const attempts = parsed.attempts ?? [];
  const reportExists = existsSync(join(dir, LAYOUT.report)) && readText(join(dir, LAYOUT.report)).trim() !== "";
  const exportEntries = walkFiles(join(dir, LAYOUT.exportDir)).filter((entry) => entry.path !== "receipt.json");
  for (const entry of exportEntries) {
    if (entry.type !== "file") problems.push(`export ${entry.path} is not a regular file`);
    const denied = denyName(entry.path, CONTRACT.exportDeny);
    if (denied) problems.push(`export ${entry.path} matches ${denied}`);
  }
  if (exportEntries.length > 0 && !reportExists) problems.push("export without a report");
  if (reportExists && attempts.length === 0) problems.push("report without a run");
  if (problems.length > 0) return { ok: false, id, problems };
  const files = exportEntries.filter((entry) => entry.type === "file");
  const digest = files.length > 0 ? digestOf(files) : null;
  const receiptLines = (readText(join(dir, LAYOUT.receipts)) ?? "").split("\n").filter((line) => line.trim());
  let receipt = null;
  for (const line of receiptLines) {
    try {
      const row = JSON.parse(line);
      if (digest && row.digest === digest) receipt = row;
    } catch {
      problems.push("bad export receipt");
      return { ok: false, id, problems };
    }
  }
  const last = attempts.at(-1) ?? null;
  let stage = "briefed";
  if (last && last.ended === null && last.executor === "cursor_cli" && last.host && isLive(last.host.pid, last.host.bootId)) stage = "running";
  else if (last && last.ended === null && last.executor === "in_session" && !reportExists) stage = "running";
  else if (!reportExists && !last) stage = "briefed";
  else if (!reportExists && last && last.ended === null) stage = "interrupted";
  else if (!reportExists && last && last.ended.exit !== 0) stage = "failed";
  else if (!reportExists && last && last.ended.exit === 0) stage = "failed";
  else if (reportExists && files.length === 0) stage = "reported";
  else if (reportExists && receipt) stage = "exported";
  else stage = "curated";
  const reason = stage === "failed" && last?.ended?.exit === 0 ? "no_report" : stage === "failed" ? "exit_nonzero" : null;
  return { ok: true, id, role, attempts, stage, digest, files, receipt, reason, last };
}

function runnableNames() {
  return [...CONTRACT.roster.routine, CONTRACT.roster.investigator].map((role) => role.id).join(", ");
}

function nextAction(loaded) {
  if (!loaded.ok) return loaded.problems.join("; ");
  if (loaded.stage === "briefed" || loaded.stage === "interrupted" || loaded.stage === "failed") {
    const why = loaded.reason === "no_report" ? " (agent exited 0 without a report)" : "";
    return `bash scripts/run-task.sh ${loaded.id}${why}`;
  }
  if (loaded.stage === "running") return `wait: attempt ${loaded.last.n} (${loaded.last.executor}) is live`;
  if (loaded.stage === "reported") return `copy reviewed files into workspace/items/${loaded.id}/export/, then bash scripts/export-drive.sh ${loaded.id}`;
  if (loaded.stage === "curated") return `bash scripts/export-drive.sh ${loaded.id}`;
  return `done: ${loaded.receipt.folder}; change export/ to publish a new version`;
}

function view(loaded) {
  const role = loaded.ok ? loaded.role : null;
  return {
    id: loaded.id,
    stage: loaded.ok ? loaded.stage : "invalid",
    role: role ? role.id : null,
    runnable: Boolean(role && role.kind !== "instruction_only"),
    perplexity: role ? grantedTools(role) : [],
    lastExit: loaded.ok && loaded.last?.ended ? loaded.last.ended.exit : null,
    next: nextAction(loaded),
    problems: loaded.ok ? [] : loaded.problems,
  };
}

function printStatus(loaded, asJson) {
  const body = view(loaded);
  if (asJson) {
    console.log(JSON.stringify(body));
    return loaded.ok ? 0 : 1;
  }
  const tools = body.perplexity.length > 0 ? body.perplexity.join(", ") : "none";
  const kind = body.runnable ? "runnable" : "instruction-only";
  console.log(`${body.id}  ${body.stage}  ${body.role ?? "-"} (${kind})  perplexity: ${tools}`);
  console.log(`next: ${body.next}`);
  return loaded.ok ? 0 : 1;
}

function listItems() {
  const dir = join(ROOT, "workspace", "items");
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((name) => parseId(name)).sort();
}

function missingEnv(need, env) {
  return envNeeded(CONTRACT, need).filter((entry) => !env[entry.name]).map((entry) => entry.name);
}

function connectorKind() {
  const path = join(ROOT, ".cursor", "mcp.json");
  if (!existsSync(path)) return "absent";
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    const server = parsed.mcpServers?.perplexity;
    if (!server) return "absent";
    if (server.url === CONTRACT.perplexity.url && !server.command) return "hosted";
    if (server.command) return "stdio";
  } catch {
    return "absent";
  }
  return "absent";
}

function repoFacts() {
  const pkg = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8"));
  const dependencyNames = Object.keys({ ...pkg.dependencies, ...pkg.devDependencies });
  const listed = spawnSync("git", ["ls-files", "-z"], { cwd: ROOT, encoding: "utf8" });
  const foreignContractImporters = [];
  for (const path of (listed.stdout ?? "").split("\0")) {
    if (!path || path === "scripts/clan.mjs") continue;
    if (!existsSync(join(ROOT, path))) continue;
    const text = readFileSync(join(ROOT, path), "utf8");
    if (/from\s+["']\.\/clan-contract\.mjs["']/.test(text)) foreignContractImporters.push(path);
  }
  return { dependencyNames, foreignContractImporters };
}

function spliceBlock(text, marker, body) {
  const start = `<!-- clan:${marker} -->`;
  const end = `<!-- /clan:${marker} -->`;
  const open = text.indexOf(start);
  const close = text.indexOf(end);
  if (open < 0 || close < open) return null;
  return `${text.slice(0, open + start.length)}\n${body.replace(/\n$/, "")}\n${text.slice(close)}`;
}

function performSync(check) {
  const problems = validateContract(CONTRACT, repoFacts());
  if (problems.length > 0) return fail(problems.join("; "));
  for (const artifact of artifacts()) {
    const path = join(ROOT, artifact.path);
    if (artifact.kind === "file") {
      const current = readText(path);
      if (check) {
        if (current !== artifact.text) return fail(`drift ${artifact.path}`);
      } else writeFileSync(path, artifact.text);
    } else {
      const current = readText(path);
      const next = current === null ? null : spliceBlock(current, artifact.marker, artifact.text);
      if (next === null) return fail(`missing clan block ${artifact.marker} in ${artifact.path}`);
      if (check) {
        if (next !== current) return fail(`drift ${artifact.path}#${artifact.marker}`);
      } else writeFileSync(path, next);
    }
  }
  if (!check) console.log("clan: synced");
  return 0;
}

function appendJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value)}\n`, { flag: "a" });
}

function planRun(loaded, env) {
  if (!loaded.ok) return { kind: "refuse", message: loaded.problems.join("; ") };
  if (env.CLAN_ACTIVE_ITEM) return { kind: "refuse", message: `nested run inside ${env.CLAN_ACTIVE_ITEM}` };
  if (loaded.stage === "running") return { kind: "refuse", message: nextAction(loaded) };
  if (loaded.stage === "reported" || loaded.stage === "curated" || loaded.stage === "exported") {
    return { kind: "noop", message: `${loaded.id} is ${loaded.stage}; delete report.md to redo` };
  }
  const tools = grantedTools(loaded.role);
  let warning = "";
  if (tools.length > 0) {
    const missing = missingEnv("perplexity", env);
    if (missing.length > 0) return { kind: "refuse", message: `${loaded.id} runs as ${loaded.role.id} (${tools.join(", ")}) and needs ${missing.join(", ")}. Set it in .env.local or the injected secret store.` };
    const connector = connectorKind();
    if (connector === "absent" && !env.CURSOR_AGENT) {
      return { kind: "refuse", message: "copy config/mcp.example.json into .cursor/mcp.json (gitignored), then enable the perplexity server. Do not write the key into the file." };
    }
    if (connector === "stdio") warning = "perplexity is a local stdio server; the hosted URL is the supported connector";
  }
  const inside = Boolean(env.CURSOR_AGENT);
  const onPath = (env.PATH ?? "").split(":").some((dir) => dir && existsSync(join(dir, "agent")));
  if (!inside && !onPath) return { kind: "refuse", message: "Install Cursor CLI first" };
  const n = (loaded.attempts.at(-1)?.n ?? 0) + 1;
  const reportLine = inside
    ? `Write workspace/items/${loaded.id}/report.md with the headings outcome, changed files, validation, blockers, and next action. This session is the executor, so no second agent is spawned.`
    : "Print the report as your final message with the headings outcome, changed files, validation, blockers, and next action. Do not write the report file yourself. Print mode does not apply file edits.";
  const prompt = [
    `Read AGENTS.md, skills/perplexity-search-router/SKILL.md, and workspace/items/${loaded.id}/brief.md.`,
    `You are ${loaded.role.title}. Duty: ${loaded.role.duty}.`,
    tools.length > 0 ? `Perplexity tools for this role: ${tools.join(", ")}. Do not call any other Perplexity tool.` : "Do not call Perplexity tools.",
    "Do not spawn another Cursor CLI. Do not push, deploy, or send messages.",
    reportLine,
  ].join(" ");
  const deny = [
    ...deniedTools(CONTRACT, loaded.role).map((tool) => `Mcp(${CONTRACT.perplexity.server}:${tool})`),
    `Write(workspace/items/${loaded.id}/${LAYOUT.brief})`,
    `Write(workspace/items/${loaded.id}/${LAYOUT.runs})`,
    `Write(workspace/items/${loaded.id}/${LAYOUT.receipts})`,
    `Write(workspace/items/${loaded.id}/${LAYOUT.exportDir}/**)`,
  ];
  return { kind: "go", id: loaded.id, n, role: loaded.role, inside, prompt, deny, tools, warning };
}

function writeDeny(plan) {
  const path = join(ROOT, ".cursor", "cli.json");
  if (existsSync(path)) {
    const current = readText(path) ?? "";
    if (!current.includes(CLI_MARKER)) throw new Error(".cursor/cli.json exists and is not a clan deny file");
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify({ thunderstoneClan: CLI_MARKER, permissions: { allow: [], deny: plan.deny } }, null, 2)}\n`);
  return path;
}

function performRun(plan, env) {
  if (plan.warning) console.error(`clan: ${plan.warning}`);
  const dir = itemDir(plan.id);
  mkdirSync(dir, { recursive: true });
  const runs = join(dir, LAYOUT.runs);
  const now = new Date().toISOString();
  if (plan.inside) {
    appendJson(runs, { v: 1, event: "start", n: plan.n, executor: "in_session", role: plan.role.id, at: now });
    console.log(plan.prompt);
    return 0;
  }
  let cliPath;
  try {
    cliPath = writeDeny(plan);
  } catch (error) {
    return fail(error.message);
  }
  appendJson(runs, { v: 1, event: "start", n: plan.n, executor: "cursor_cli", role: plan.role.id, at: now, pid: process.pid, boot: bootId() });
  let status = 1;
  let stdout = "";
  try {
    const child = spawnSync("agent", ["-p", "--output-format", "text", plan.prompt], {
      cwd: ROOT,
      env: { ...env, CLAN_ACTIVE_ITEM: plan.id },
      encoding: "utf8",
    });
    status = child.status ?? 1;
    stdout = child.stdout ?? "";
    if (child.stderr) process.stderr.write(child.stderr);
  } finally {
    const current = readText(cliPath) ?? "";
    if (current.includes(CLI_MARKER)) rmSync(cliPath, { force: true });
  }
  if (status === 0 && stdout.trim()) writeFileSync(join(dir, LAYOUT.report), `${stdout.trim()}\n`);
  appendJson(runs, { v: 1, event: "end", n: plan.n, at: new Date().toISOString(), exit: status });
  const after = loadItem(plan.id);
  printStatus(after, false);
  return after.ok && after.stage === "reported" ? 0 : 1;
}

function performExport(loaded, env) {
  if (!loaded.ok) return fail(loaded.problems.join("; "));
  if (loaded.stage === "exported") {
    console.log(`exported ${loaded.id} as ${loaded.receipt.folder}`);
    return 0;
  }
  if (loaded.stage !== "curated") return fail(`${loaded.id} is ${loaded.stage}. next: ${nextAction(loaded)}`);
  const missing = missingEnv("export", env);
  if (missing.length > 0) return fail(`needs ${missing.join(", ")}`);
  const files = loaded.files.map((entry) => join(itemDir(loaded.id), LAYOUT.exportDir, entry.path));
  const hygiene = spawnSync("bash", [join(ROOT, "scripts", "check-hygiene.sh"), "--files", "--", ...files], { encoding: "utf8" });
  if (hygiene.stdout) process.stdout.write(hygiene.stdout);
  if (hygiene.stderr) process.stderr.write(hygiene.stderr);
  if (hygiene.status !== 0) return fail("export files failed hygiene");
  const folder = `${loaded.id}/${loaded.digest.slice(0, 12)}`;
  const remote = `${env.GDRIVE_REMOTE}:${env.DRIVE_EXPORT_ROOT.replace(/\/$/, "")}/${folder}`;
  const args = ["copy", join(itemDir(loaded.id), LAYOUT.exportDir), remote, "--immutable"];
  for (const pattern of CONTRACT.exportDeny) args.push("--exclude", pattern);
  const copy = spawnSync("rclone", args, { stdio: "inherit", env });
  if (copy.status !== 0) return fail("rclone copy failed");
  appendJson(join(itemDir(loaded.id), LAYOUT.receipts), { digest: loaded.digest, folder, at: new Date().toISOString() });
  console.log(`exported ${loaded.id} as ${folder}`);
  return 0;
}

function commandNew(id, roleId) {
  const role = findRole(CONTRACT, roleId);
  if (!role) return fail(`unknown role ${roleId}. Runnable roles: ${runnableNames()}`);
  if (role.kind === "instruction_only") return fail(`${roleId} is instruction-only (${role.duty}). Runnable roles: ${runnableNames()}`);
  const dir = itemDir(id);
  const brief = join(dir, LAYOUT.brief);
  if (existsSync(brief)) {
    const current = readText(brief).split("\n", 1)[0];
    if (current === `role: ${roleId}`) {
      console.log(`${id} already briefed as ${roleId}`);
      return 0;
    }
    return fail(`${id} is already briefed as ${current}`);
  }
  mkdirSync(dir, { recursive: true });
  writeFileSync(brief, `role: ${roleId}\n\n# ${id}\n\n`);
  console.log(`briefed ${id} as ${roleId}`);
  return 0;
}

function main(argv = process.argv.slice(2), env = process.env) {
  const [verb, ...rest] = argv;
  if (verb === "sync") return performSync(rest.includes("--check"));
  if (verb === "labels") {
    if (rest.includes("--signal")) {
      console.log(signalLabels(CONTRACT, "monitor").join("\n"));
      return 0;
    }
    if (rest.includes("--changelog")) {
      console.log(JSON.stringify(changelogSections(CONTRACT)));
      return 0;
    }
    console.log(labelLines(CONTRACT).join("\n"));
    return 0;
  }
  if (verb === "status") {
    const asJson = rest.includes("--json");
    const id = rest.find((arg) => !arg.startsWith("--"));
    if (!id) {
      const ids = listItems();
      if (ids.length === 0) return 0;
      let code = 0;
      for (const item of ids) code = Math.max(code, printStatus(loadItem(item), asJson));
      return code;
    }
    if (!parseId(id)) return fail(`id ${id} must look like TASK-001`);
    return printStatus(loadItem(id), asJson);
  }
  if (verb === "new") {
    const id = parseId(rest[0] ?? "");
    const roleFlag = rest.indexOf("--role");
    if (!id || roleFlag < 0 || !rest[roleFlag + 1]) return fail("usage: clan new ID --role ROLE");
    return commandNew(id, rest[roleFlag + 1]);
  }
  if (verb === "run") {
    if (env.CLAN_ENTRY !== "run-task") return fail("run scripts/run-task.sh ID");
    const id = parseId(rest[0] ?? "");
    if (!id) return fail("usage: run-task.sh ID");
    const plan = planRun(loadItem(id), env);
    if (plan.kind === "refuse") return fail(plan.message);
    if (plan.kind === "noop") {
      console.log(plan.message);
      return 0;
    }
    return performRun(plan, env);
  }
  if (verb === "export") {
    if (env.CLAN_ENTRY !== "export-drive") return fail("run scripts/export-drive.sh ID");
    const id = parseId(rest[0] ?? "");
    if (!id) return fail("usage: export-drive.sh ID");
    return performExport(loadItem(id), env);
  }
  return fail("usage: clan status|new|run|export|labels|sync");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main());
}

export { main, loadItem, ROOT };
