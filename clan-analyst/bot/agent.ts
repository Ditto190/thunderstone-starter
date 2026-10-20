import { defineAgent } from "@cursor/bdk";

export default defineAgent({
  name: "clan-analyst",
  description: "Reads the Thunderstone review registry and reports code-analysis findings.",
  model: {
    id: "grok-4.5",
    params: [
      { id: "effort", value: "high" },
      { id: "fast", value: "true" },
    ],
  },
});
