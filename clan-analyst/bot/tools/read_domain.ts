import { defineTool } from "@cursor/bdk/tools";
import { domainSnapshot } from "../../../services/analysis/analyze.mjs";

export default defineTool({
  description: "Return the Thunderstone review registry: stages, signals, command paths, and analyzer rules.",
  effect: "read",
  async execute() {
    return domainSnapshot();
  },
});
