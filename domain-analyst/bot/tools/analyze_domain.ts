import { defineTool } from "@cursor/bdk/tools";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { analyzeWorkspace } from "../../../services/domain-analysis/analyze.mjs";

const repoRoot = path.resolve(fileURLToPath(new URL(".", import.meta.url)), "..", "..", "..");

const Report = z.object({
  clan: z.string(),
  stage: z.string().nullable(),
  reason: z.string(),
  findings: z.array(
    z.object({
      kind: z.string(),
      id: z.string(),
      detail: z.string(),
    }),
  ),
});

export default defineTool({
  description: "Analyze the checkout against domain stage rules, roster, and documented script paths.",
  effect: "read",
  inputSchema: z.object({
    signals: z.record(z.string(), z.boolean()).optional(),
  }),
  outputSchema: Report,
  async execute({ signals }) {
    const report = analyzeWorkspace(repoRoot, signals);
    return {
      clan: report.clan,
      stage: report.stage,
      reason: report.reason,
      findings: report.findings,
    };
  },
});
