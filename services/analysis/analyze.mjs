import { ANALYZERS, COMMANDS, SIGNALS, STAGE_ORDER } from "./domain.mjs";

const CHECKS = {
  "line-pattern": linePatternFindings,
  "script-ref": scriptRefFindings,
};

const SCRIPT_REF = /(?<![\w./-])scripts\/[A-Za-z0-9._/-]+/g;

export function domainSnapshot() {
  return {
    stages: STAGE_ORDER,
    signals: SIGNALS,
    commands: COMMANDS,
    analyzers: ANALYZERS,
  };
}

export function adviseStage(flags) {
  const hits = Object.entries(SIGNALS).filter(([name, rule]) => {
    if (flags[name] !== true) return false;
    if (rule.needsDirty && flags.dirty !== true) return false;
    return true;
  });
  const stage = STAGE_ORDER.find((id) => hits.some(([, rule]) => rule.stage === id)) ?? null;
  const reason = hits
    .filter(([, rule]) => rule.stage === stage)
    .map(([name]) => name)
    .join(",");
  return { stage, reason: stage ? reason : "none" };
}

export function analyzeText(text, options = {}) {
  const exists = options.exists ?? (() => false);
  const findings = [];
  for (const analyzer of ANALYZERS) {
    for (const rule of analyzer.rules) {
      const check = CHECKS[rule.check];
      if (!check) {
        throw new Error(`unknown check: ${rule.check}`);
      }
      findings.push(...check(analyzer, rule, text, exists));
    }
  }
  return { findings };
}

function linePatternFindings(analyzer, rule, text) {
  const re = new RegExp(rule.pattern, "i");
  const findings = [];
  const lines = String(text).split("\n");
  for (let i = 0; i < lines.length; i += 1) {
    if (!re.test(lines[i])) continue;
    findings.push({
      analyzer: analyzer.id,
      rule: rule.id,
      severity: rule.severity,
      line: i + 1,
      summary: rule.summary,
    });
  }
  return findings;
}

function scriptRefFindings(analyzer, rule, text, exists) {
  const known = new Set(Object.values(COMMANDS));
  const seen = new Set();
  const findings = [];
  for (const match of String(text).matchAll(SCRIPT_REF)) {
    const ref = match[0];
    if (seen.has(ref) || ref.includes("..")) continue;
    seen.add(ref);
    const registered = known.has(ref);
    const present = exists(ref) === true;
    if (registered && present) continue;
    findings.push({
      analyzer: analyzer.id,
      rule: rule.id,
      severity: rule.severity,
      path: ref,
      summary: registered ? "registry path missing on disk" : rule.summary,
    });
  }
  return findings;
}
