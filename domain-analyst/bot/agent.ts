import { defineAgent } from "@cursor/bdk";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(fileURLToPath(new URL(".", import.meta.url)), "..", "..");

export default defineAgent({
  description: "Reads Thunderstone domain config and reports stage plus doc drift.",
  model: {
    id: "grok-4.5",
    params: [
      { id: "effort", value: "high" },
      { id: "fast", value: "true" },
    ],
  },
  local: { cwd: repoRoot },
});
