import { defineTool } from "@cursor/bdk/tools";
import { z } from "zod";
import {
  loadDomainRegistry,
  nextStages,
  resolveDomain,
} from "../lib/domain-model.js";

export default defineTool({
  description:
    "Load the thunderstone domain registry entry: lanes, maintainer subagent, and allowed stage transitions.",
  effect: "read",
  inputSchema: z.object({
    domainId: z
      .string()
      .describe("Registry id, e.g. pr_orchestration or starter_runtime"),
    currentStage: z
      .enum(["monitor", "triage", "build"])
      .optional()
      .describe("Optional stage-router stage for transition hints"),
  }),
  async execute({ domainId, currentStage }) {
    const registry = loadDomainRegistry();
    const entry = resolveDomain(registry, domainId);
    const transitions =
      currentStage === undefined ? [] : [...nextStages(registry, currentStage)];
    return {
      clan: registry.clan,
      entry,
      nextStages: transitions,
      allDomainIds: registry.entries.map((e) => e.id),
    };
  },
});
