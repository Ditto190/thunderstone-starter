import { Agent, CursorAgentError } from "@cursor/sdk";

const prompt = process.argv.slice(2).join(" ").trim();
if (!prompt) {
  console.error("usage: node scripts/env-run.mjs node scripts/cursor-agent.mjs <prompt>");
  process.exit(1);
}

const apiKey = process.env.CURSOR_API_KEY;
if (!apiKey) {
  console.error("startup failed: CURSOR_API_KEY is missing, retryable=false");
  process.exit(1);
}

try {
  const result = await Agent.prompt(prompt, {
    apiKey,
    model: { id: "composer-2" },
    cloud: {
      repos: [
        {
          url: "https://github.com/Ditto190/thunderstone-starter",
          startingRef: "main",
        },
      ],
      autoCreatePR: true,
      skipReviewerRequest: true,
    },
    mcpServers: {
      "xai-docs": { url: "https://docs.x.ai/api/mcp" },
    },
  });
  console.log(`${result.status} run=${result.id}`);
  if (result.status === "error") {
    console.error(result.error?.message ?? "run failed");
    process.exit(2);
  }
  if (result.status !== "finished") process.exit(2);
  if (result.result) console.log(result.result);
} catch (err) {
  if (err instanceof CursorAgentError) {
    console.error(`startup failed: ${err.message}, retryable=${err.isRetryable}`);
    process.exit(1);
  }
  throw err;
}
