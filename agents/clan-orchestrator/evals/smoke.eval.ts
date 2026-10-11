import { defineEval, includes } from "@cursor/bdk/evals";

export default defineEval({
  tags: ["smoke"],
  cases: [
    {
      id: "domain-lanes",
      description: "Agent uses resolve_domain before discussing PR lanes.",
      async test(t) {
        await t.send(
          "For domain pr_orchestration at triage stage: call resolve_domain, then list the lanes in one sentence.",
        );
        t.succeeded();
        t.calledTool("resolve_domain");
        t.check(t.reply, includes(/lane|review/i));
      },
    },
  ],
});
