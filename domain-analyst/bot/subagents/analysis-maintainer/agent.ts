import { defineAgent } from "@cursor/bdk";

export default defineAgent({
  description:
    "Code analysis maintainer. Use when the analyzer, dispatch routes, or Vercel handlers drift from config/domain.",
});
