import { defineEval } from "@cursor/bdk/evals";

export default defineEval({
  tags: ["smoke"],
  description: "A snippet with a marker is analyzed with analyze_text.",
  async test(t) {
    await t.send("Analyze this snippet and report findings: TODO ship the registry");
    t.succeeded();
    t.calledTool("analyze_text");
  },
});
