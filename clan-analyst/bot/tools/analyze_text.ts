import { defineTool } from "@cursor/bdk/tools";
import { z } from "zod";
import { adviseStage, analyzeText, type AnalysisReport } from "../../../services/analysis/analyze.mjs";
import { scriptExists } from "../../../services/analysis/server.mjs";

const signalsSchema = z.record(z.string(), z.boolean());

export type { AnalysisReport };

export default defineTool({
  description:
    "Analyze text with the review registry. Optional signals select a stage. Use read_domain first if the signal names are unknown.",
  effect: "read",
  inputSchema: z.object({
    text: z.string().max(64_000),
    signals: signalsSchema.optional(),
  }),
  async execute({ text, signals }): Promise<AnalysisReport> {
    const analyzed = analyzeText(text, { exists: scriptExists });
    const stage = signals ? adviseStage(signals) : null;
    return {
      findings: analyzed.findings,
      stage,
    };
  },
});
