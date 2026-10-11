import { analyzeWorkspace } from "./analyze.mjs";
import { repoRootFromHere } from "./load.mjs";
import { fileURLToPath } from "node:url";

const root = repoRootFromHere(fileURLToPath(new URL(".", import.meta.url)));
const raw = process.argv[2];
const signals = raw ? JSON.parse(raw) : undefined;
process.stdout.write(`${JSON.stringify(analyzeWorkspace(root, signals))}\n`);
