import { existsSync } from "node:fs";
if (!process.env.CI && process.env.HUSKY !== "0" && existsSync(".git")) {
  const { default: husky } = await import("husky");
  console.log(husky());
}
