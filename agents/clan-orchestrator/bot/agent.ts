import { defineAgent } from "@cursor/bdk";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const starterRoot = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
);

export default defineAgent({
  model: {
    id: "grok-4.5",
    params: [
      { id: "effort", value: "high" },
      { id: "fast", value: "true" },
    ],
  },
  local: {
    cwd: starterRoot,
  },
});
