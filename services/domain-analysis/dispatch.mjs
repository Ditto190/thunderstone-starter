import { analyzeWorkspace, blankSignals } from "./analyze.mjs";
import { loadDomain, repoRootFromHere } from "./load.mjs";
import { fileURLToPath } from "node:url";

const root = repoRootFromHere(fileURLToPath(new URL(".", import.meta.url)));

export function dispatch({ method, pathname, body, repoRoot = root }) {
  if (method === "GET" && (pathname === "/health" || pathname === "/api/health")) {
    return { status: 200, body: { ok: true } };
  }
  if (method === "GET" && (pathname === "/v1/domain" || pathname === "/api/v1/domain")) {
    const domain = loadDomain(repoRoot);
    return {
      status: 200,
      body: {
        signals: domain.stages.signals,
        rules: domain.stages.rules.map((rule) => ({
          stage: rule.stage,
          reason: rule.reason,
        })),
        roles: domain.roster.roles,
        docSources: domain.docSources.sources,
      },
    };
  }
  if (
    (method === "GET" || method === "POST") &&
    (pathname === "/v1/analyze" || pathname === "/api/v1/analyze")
  ) {
    try {
      const signals = method === "POST" ? body && body.signals : blankSignals(loadDomain(repoRoot).stages);
      const report = analyzeWorkspace(repoRoot, signals);
      return { status: 200, body: report };
    } catch (error) {
      return { status: 400, body: { error: error.message } };
    }
  }
  return { status: 404, body: { error: "not found" } };
}
