import { readFileSync } from "node:fs";
import { adviseStage, analyzeText } from "./analyze.mjs";
import { scriptExists } from "./server.mjs";

const file = process.argv[2];
if (!file || file.startsWith("/") || file.includes("..")) {
  process.stderr.write("usage: node services/analysis/cli.mjs <relative-file>\n");
  process.exit(2);
}

const text = readFileSync(file, "utf8");
const report = {
  path: file,
  ...analyzeText(text, { exists: scriptExists }),
  stage: adviseStage({ dirty: true, docsOnly: file.endsWith(".md") }),
};
process.stdout.write(`${JSON.stringify(report)}\n`);
