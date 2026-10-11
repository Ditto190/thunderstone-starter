import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { loadDomain } from "./load.mjs";

export function blankSignals(stages) {
  return Object.fromEntries(stages.signals.map((name) => [name, false]));
}

export function normalizeSignals(stages, input) {
  const signals = blankSignals(stages);
  if (input == null) return signals;
  if (typeof input !== "object" || Array.isArray(input)) {
    throw new Error("signals must be an object");
  }
  for (const [key, value] of Object.entries(input)) {
    if (!Object.hasOwn(signals, key)) throw new Error(`unknown signal ${key}`);
    if (typeof value !== "boolean") throw new Error(`signal ${key} must be boolean`);
    signals[key] = value;
  }
  return signals;
}

export function matchPredicate(expr, signals) {
  switch (expr.op) {
    case "signal":
      return signals[expr.name] === true;
    case "any":
      return expr.of.some((item) => matchPredicate(item, signals));
    case "all":
      return expr.of.every((item) => matchPredicate(item, signals));
    default: {
      const op = expr && expr.op;
      throw new Error(`unknown predicate op: ${op}`);
    }
  }
}

export function selectStage(stages, signals) {
  for (const rule of stages.rules) {
    if (matchPredicate(rule.when, signals)) {
      return { stage: rule.stage, reason: rule.reason };
    }
  }
  return { stage: null, reason: "no stage rule matched" };
}

export function scanDocs(root, domain) {
  const findings = [];
  const pattern = new RegExp(domain.docSources.scriptPattern, "g");
  for (const rel of domain.docSources.sources) {
    const abs = path.join(root, rel);
    if (!existsSync(abs)) {
      findings.push({ kind: "docs-drift", id: rel, detail: "documented source missing" });
      continue;
    }
    const text = readFileSync(abs, "utf8");
    for (const match of text.matchAll(pattern)) {
      const script = match[1];
      if (!existsSync(path.join(root, script))) {
        findings.push({
          kind: "docs-drift",
          id: `${rel}:${script}`,
          detail: "documented script path is missing",
        });
      }
    }
  }
  const agents = path.join(root, "AGENTS.md");
  const agentsText = existsSync(agents) ? readFileSync(agents, "utf8") : "";
  for (const role of domain.roster.roles) {
    if (!agentsText.includes(role.name)) {
      findings.push({
        kind: "docs-drift",
        id: `roster:${role.id}`,
        detail: "role name missing from AGENTS.md",
      });
    }
  }
  return findings;
}

export function analyzeWorkspace(root, signalInput) {
  const domain = loadDomain(root);
  const signals = normalizeSignals(domain.stages, signalInput);
  const stage = selectStage(domain.stages, signals);
  const findings = scanDocs(root, domain);
  if (stage.stage) {
    findings.unshift({ kind: "stage", id: stage.stage, detail: stage.reason });
  }
  return {
    clan: clanName(domain.clan),
    stage: stage.stage,
    reason: stage.reason,
    signals,
    roles: domain.roster.roles.map((role) => ({
      id: role.id,
      name: role.name,
      owns: role.owns,
    })),
    findings,
  };
}

function clanName(yaml) {
  const match = yaml.match(/^clan:\s*(\S+)\s*$/m);
  if (!match) throw new Error("clan name missing");
  return match[1];
}
