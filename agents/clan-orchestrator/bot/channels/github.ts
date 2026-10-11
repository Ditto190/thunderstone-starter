import {
  defaultGitHubAuth,
  githubChannel,
} from "@cursor/bdk/channels/github";

const REVIEW_ACTIONS = new Set(["opened", "reopened", "ready_for_review"]);

export default githubChannel({
  botName: "clan-orchestrator",
  cursorAccount: { repos: ["Ditto190/thunderstone-starter"] },
  onPullRequest: (ctx, pr) => {
    if (!REVIEW_ACTIONS.has(pr.action) || pr.draft) {
      return null;
    }

    return {
      auth: defaultGitHubAuth(ctx),
      title: `Clan review ${ctx.repository.fullName}#${pr.number}`,
      context: [
        `Domain id: pr_orchestration. Call resolve_domain, then inspect_pr on ${pr.url}. Produce findings by lane (review_and_ship, pr_review_canvas). Do not post GitHub reviews.`,
      ],
    };
  },
});
