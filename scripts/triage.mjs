import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const root = resolve(new URL("..", import.meta.url).pathname);

/**
 * @typedef {{ kind: "file", path: string }} FileEvidence
 * @typedef {{ kind: "env-name", name: string }} EnvEvidence
 * @typedef {{ kind: "operator" }} OperatorEvidence
 * @typedef {FileEvidence | EnvEvidence | OperatorEvidence} Evidence
 * @typedef {{ files: Set<string>, envNames: Set<string> }} Present
 * @typedef {{ state: "ready" | "operator" | "blocked", because?: string }} LaneState
 */

/** @param {never} value */
function unreachable(value) {
  throw new Error(`Unhandled variant: ${JSON.stringify(value)}`);
}

/**
 * Status is computed. The document stores evidence, never a status string.
 * @param {Evidence} evidence
 * @param {Present} present
 * @returns {LaneState}
 */
export function deriveLane(evidence, present) {
  switch (evidence.kind) {
    case "file":
      return present.files.has(evidence.path)
        ? { state: "ready" }
        : { state: "blocked", because: `missing ${evidence.path}` };
    case "env-name":
      return present.envNames.has(evidence.name)
        ? { state: "operator" }
        : { state: "blocked", because: `${evidence.name} is not named in .env.example` };
    case "operator":
      return { state: "operator" };
    default:
      return unreachable(evidence);
  }
}

/** @param {string} text */
export function envNamesInExample(text) {
  const names = new Set();
  for (const line of text.split("\n")) {
    const match = /^(?:export\s+)?([A-Z][A-Z0-9_]*)=/.exec(line.trim());
    if (match) names.add(match[1]);
  }
  return names;
}

/** @param {unknown} doc */
function assertDoc(doc) {
  if (!doc || typeof doc !== "object") throw new Error("e2e document is not an object");
  const record = /** @type {{ lanes?: unknown, connectors?: unknown }} */ (doc);
  if (!Array.isArray(record.lanes) || !Array.isArray(record.connectors)) {
    throw new Error("e2e document needs lanes and connectors arrays");
  }
  return record;
}

/** @param {string} dir */
export function loadModel(dir) {
  const doc = assertDoc(JSON.parse(readFileSync(resolve(dir, "config/e2e.json"), "utf8")));
  const example = readFileSync(resolve(dir, ".env.example"), "utf8");
  /** @type {Present} */
  const present = {
    files: new Set(),
    envNames: envNamesInExample(example),
  };
  for (const lane of doc.lanes) {
    if (lane.evidence?.kind === "file") {
      try {
        readFileSync(resolve(dir, lane.evidence.path));
        present.files.add(lane.evidence.path);
      } catch {
        // Missing evidence stays out of the set. deriveLane reports blocked.
      }
    }
  }
  return { doc, present };
}

/**
 * @param {ReturnType<typeof loadModel>["doc"]} doc
 */
export function mcpServers(doc) {
  /** @type {Record<string, object>} */
  const mcpServers = {};
  for (const connector of doc.connectors) {
    switch (connector.kind) {
      case "remote-http":
        mcpServers[connector.id] = remoteServer(connector);
        break;
      case "stdio":
        mcpServers[connector.id] = {
          command: connector.command,
          args: connector.args,
        };
        break;
      default:
        unreachable(connector.kind);
    }
  }
  return { mcpServers };
}

/** @param {{ auth: { type: string, env?: string }, url: string }} connector */
function remoteServer(connector) {
  switch (connector.auth.type) {
    case "bearer":
      return {
        url: connector.url,
        headers: { Authorization: `Bearer \${env:${connector.auth.env}}` },
      };
    case "none":
    case "oauth":
      return { url: connector.url };
    default:
      return unreachable(connector.auth.type);
  }
}

function printReport(model) {
  for (const lane of model.doc.lanes) {
    const state = deriveLane(lane.evidence, model.present);
    const because = state.because ? ` ${state.because}` : "";
    process.stdout.write(`${state.state}\t${lane.id}\t${lane.owner}\t${lane.action}${because}\n`);
  }
}

function blockedCount(model) {
  return model.doc.lanes.filter((lane) => deriveLane(lane.evidence, model.present).state === "blocked").length;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const command = process.argv[2] ?? "report";
  const model = loadModel(root);
  switch (command) {
    case "report":
      printReport(model);
      break;
    case "check":
      if (blockedCount(model) > 0) {
        printReport(model);
        process.exit(1);
      }
      break;
    case "mcp":
      process.stdout.write(`${JSON.stringify(mcpServers(model.doc), null, 2)}\n`);
      break;
    default:
      throw new Error("Usage: node scripts/triage.mjs [report|check|mcp]");
  }
}
