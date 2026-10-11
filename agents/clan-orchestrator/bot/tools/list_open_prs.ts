import { defineTool } from "@cursor/bdk/tools";
import { z } from "zod";

export default defineTool({
  description:
    "List open pull requests for a GitHub repository (read-only).",
  effect: "read",
  inputSchema: z.object({
    owner: z.string(),
    repo: z.string(),
    limit: z.number().int().min(1).max(30).default(15),
  }),
  async execute({ owner, repo, limit }, ctx) {
    const octokit = await ctx.host.github.getOctokit();
    const { data } = await octokit.rest.pulls.list({
      owner,
      repo,
      state: "open",
      per_page: limit,
      sort: "updated",
      direction: "desc",
    });
    return {
      count: data.length,
      pulls: data.map((pr) => ({
        number: pr.number,
        title: pr.title,
        url: pr.html_url,
        headRef: pr.head.ref,
        draft: pr.draft ?? false,
        updatedAt: pr.updated_at,
      })),
    };
  },
});
