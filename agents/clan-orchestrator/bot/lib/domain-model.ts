import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";

const stageSchema = z.enum(["monitor", "triage", "build"]);
const laneSchema = z.enum([
  "review_and_ship",
  "pr_review_canvas",
  "comment_sicko",
  "docs_reliability",
  "orchestrate",
]);

const registrySchema = z.object({
  schema_version: z.number(),
  clan: z.string(),
  stages: z.array(stageSchema),
  lanes: z.array(laneSchema),
  entries: z.array(
    z.object({
      id: z.string(),
      description: z.string(),
      lanes: z.array(laneSchema),
      maintainer_subagent: z.string(),
      stage_hints: z.array(stageSchema),
      default_repo: z.string().optional(),
    }),
  ),
  transitions: z.record(stageSchema, z.array(stageSchema)),
});

export type Stage = z.infer<typeof stageSchema>;
export type ReviewLane = z.infer<typeof laneSchema>;
export type DomainRegistry = z.infer<typeof registrySchema>;
export type DomainEntry = DomainRegistry["entries"][number];

function starterRoot(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  return join(here, "..", "..", "..", "..");
}

export function loadDomainRegistry(): DomainRegistry {
  const path = join(starterRoot(), "config", "domains", "registry.json");
  const raw = JSON.parse(readFileSync(path, "utf8")) as unknown;
  return registrySchema.parse(raw);
}

export function resolveDomain(
  registry: DomainRegistry,
  domainId: string,
): DomainEntry {
  const entry = registry.entries.find((e) => e.id === domainId);
  if (!entry) {
    const ids = registry.entries.map((e) => e.id).join(", ");
    throw new Error(`Unknown domain "${domainId}". Known: ${ids}`);
  }
  return entry;
}

export function nextStages(
  registry: DomainRegistry,
  current: Stage,
): readonly Stage[] {
  return registry.transitions[current] ?? [];
}
