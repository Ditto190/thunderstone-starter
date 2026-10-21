#!/usr/bin/env node
// Opt-in live smoke against api.cursor.com. Does not open a socket unless
// CURSOR_API_KEY is set AND --confirm is passed. Never run this from CI.
import { createClient } from "../server/client.mjs";
import { createToolbox } from "../server/tools.mjs";

const args = process.argv.slice(2);
const confirm = args.includes("--confirm");
const launch = args.includes("--launch");
const repoFlag = args.indexOf("--repo");
const repo = repoFlag >= 0 ? args[repoFlag + 1] : undefined;

function refuse(message) {
  process.stderr.write(`smoke-live: ${message}\n`);
  process.exit(2);
}

if (!confirm) refuse("--confirm is required; refusing before any network call.");
const key = (process.env.CURSOR_API_KEY || "").trim();
if (!key || /^\$\{[^}]*\}$/.test(key)) refuse("CURSOR_API_KEY is not set; refusing before any network call.");

const env = process.env;
const box = createToolbox({ env, client: createClient({ env }) });

const listed = await box.call("list_agents", { limit: 5, includeArchived: false });
if (listed.isError) {
  process.stderr.write(`smoke-live: list_agents failed: ${listed.data.error?.code ?? "error"}\n`);
  process.exit(1);
}
process.stdout.write(`list_agents ok items=${listed.data.items?.length ?? 0}\n`);

if (!launch) process.exit(0);
if (!repo) refuse("--launch requires --repo <url>.");
const launched = await box.call("launch_agent", {
  prompt: "Reply with the single word pong. Do not change files.",
  repoUrl: repo,
  confirm: true,
  autoCreatePR: false,
});
if (launched.isError) {
  process.stderr.write(`smoke-live: launch_agent failed: ${launched.data.error?.code ?? "error"}\n`);
  process.exit(1);
}
process.stdout.write(`launch_agent ok agentId=${launched.data.agentId} runId=${launched.data.runId}\n`);
