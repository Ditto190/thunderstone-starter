import { defineEval } from "@cursor/bdk/evals";

export default defineEval({
  tags: ["smoke"],
  cases: [
    {
      id: "clean-default",
      description: "A clean default branch is Build, from the tool, not a guessed stage.",
      async test(t) {
        await t.send("What stage is a clean synced default branch? Use the domain tool.");
        t.succeeded();
        t.calledTool("analyze_domain", { input: { signals: { cleanDefaultBranch: true } } });
      },
    },
  ],
});
