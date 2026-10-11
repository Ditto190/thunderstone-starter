import { readFileSync } from "node:fs";
import path from "node:path";

export function repoRootFromHere(here) {
  return path.resolve(here, "..", "..");
}

export function readJson(root, rel) {
  return JSON.parse(readFileSync(path.join(root, rel), "utf8"));
}

export function loadDomain(root) {
  const roster = readJson(root, "config/domain/roster.json");
  const stages = readJson(root, "config/domain/stages.json");
  const docSources = readJson(root, "config/domain/doc-sources.json");
  const clan = readFileSync(path.join(root, "config/clan.yaml"), "utf8");
  assertDomain(roster, stages, docSources);
  return { roster, stages, docSources, clan };
}

function assertDomain(roster, stages, docSources) {
  const ids = new Set();
  for (const role of roster.roles) {
    if (ids.has(role.id)) throw new Error(`duplicate role ${role.id}`);
    ids.add(role.id);
    if (!role.name || !role.owns) throw new Error(`role ${role.id} missing name or owns`);
  }
  const known = new Set(stages.signals);
  const seen = new Set();
  for (const rule of stages.rules) {
    if (seen.has(rule.stage)) throw new Error(`duplicate stage ${rule.stage}`);
    seen.add(rule.stage);
    walk(rule.when, known);
  }
  if (!Array.isArray(docSources.sources) || docSources.sources.length === 0) {
    throw new Error("doc sources empty");
  }
  new RegExp(docSources.scriptPattern);
}

function walk(expr, known) {
  switch (expr.op) {
    case "signal":
      if (!known.has(expr.name)) throw new Error(`unknown signal ${expr.name}`);
      return;
    case "any":
    case "all":
      if (!Array.isArray(expr.of) || expr.of.length === 0) {
        throw new Error(`${expr.op} needs of`);
      }
      for (const item of expr.of) walk(item, known);
      return;
    default: {
      const op = expr && expr.op;
      throw new Error(`unknown predicate op: ${op}`);
    }
  }
}
