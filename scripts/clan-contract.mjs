/**
 * Single owner of the clan roster, Perplexity grant, env names, and labels.
 * Committed views are rendered by artifacts(). Edit this module, then
 * `node scripts/clan.mjs sync`.
 */

export const CONTRACT = {
  schemaVersion: 2,
  clan: "thunderstone",
  authorities: { starter: "google_drive", activeCode: "github_after_promotion" },
  executor: "cursor_cli",
  recursiveAgentExecution: false,
  startup: {
    bootstrap: "sh scripts/bootstrap.sh",
    login: "bash scripts/resume.sh",
    session_resume: "bash scripts/resume.sh",
    desktop: "xfce_existing",
    terminal: "bash",
    session_manager: "tmux",
    require_systemd: false,
  },
  automation: {
    paid_tasks_on_login: false,
    checkpoint_commits: "opt_in",
    remote_push: "explicit_approval",
    drive_export: "curated_additive_only",
  },
  roster: {
    investigator: {
      kind: "investigator",
      id: "chief-investigator",
      title: "Chief Investigator",
      duty: "investigates with deep research",
    },
    routine: [
      { kind: "routine", id: "cursor-hammer", title: "Cursor-Hammer", duty: "implements", perplexity: "search" },
      { kind: "routine", id: "watcher-of-broken-things", title: "Watcher of Broken Things", duty: "verifies", perplexity: "search" },
    ],
    instructionOnly: [
      { kind: "instruction_only", id: "chief-of-chiefs", title: "Chief of Chiefs", duty: "routes tasks" },
      { kind: "instruction_only", id: "thunder-terminal", title: "Thunder-Terminal", duty: "owns the VM" },
      { kind: "instruction_only", id: "keeper-of-stone-tablets", title: "Keeper of Stone Tablets", duty: "keeps briefs and handoffs" },
    ],
  },
  perplexity: {
    server: "perplexity",
    url: "https://api.perplexity.ai/mcp",
    tokenEnv: "PERPLEXITY_API_KEY",
    tools: ["perplexity_search", "perplexity_ask", "perplexity_research", "perplexity_reason"],
    forbiddenPackages: ["@perplexity-ai/perplexity_ai", "@perplexity-ai/mcp-server"],
  },
  env: [
    { kind: "secret", name: "CURSOR_API_KEY", purpose: "Cursor CLI auth when agent login was not run" },
    { kind: "setting", name: "RCLONE_CONFIG", purpose: "Path to a protected rclone configuration" },
    { kind: "setting", name: "DRIVE_EXPORT_ROOT", purpose: "Active project Drive export path", neededFor: "export" },
    { kind: "setting", name: "ALLOW_LOCAL_COMMITS", purpose: "Set to 1 to opt in to scripts/checkpoint.sh" },
    { kind: "setting", name: "CLAN_NAME", purpose: "Clan id", default: "thunderstone" },
    { kind: "setting", name: "GDRIVE_REMOTE", purpose: "rclone remote name", default: "gdrive", neededFor: "export" },
    { kind: "setting", name: "TZ", purpose: "Local time zone", default: "Australia/Sydney" },
    { kind: "secret", name: "PERPLEXITY_API_KEY", purpose: "Bearer token for the hosted Perplexity MCP", neededFor: "perplexity" },
    { kind: "setting", name: "PERPLEXITY_BASE_URL", purpose: "Optional API origin for Perplexity's own clients; the hosted connector URL is fixed" },
    { kind: "setting", name: "PERPLEXITY_LOG", purpose: "Log level for Perplexity's own clients", default: "warn" },
  ],
  labels: [
    { name: "ci", color: "1d76db", description: "CI, workflows and git hooks", paths: [".github/workflows/**", ".husky/**"] },
    { name: "docs", color: "0075ca", description: "Documentation only", changelog: "Changed", changelogRank: 4, paths: ["docs/**", "**/*.md", "LICENSE"] },
    { name: "security", color: "b60205", description: "Security, hygiene and scanning", changelog: "Security", changelogRank: 2, paths: ["SECURITY.md", "scripts/check-hygiene.sh", ".github/workflows/security.yml", ".github/workflows/codeql.yml"] },
    { name: "deps", color: "0366d6", description: "Dependency updates", changelog: "Changed", changelogRank: 3, paths: ["package.json", "package-lock.json", ".github/dependabot.yml"] },
    { name: "agent", color: "5319e7", description: "Agent, bot and review configuration", paths: ["AGENTS.md", "config/**", ".cursor/**", ".coderabbit.yaml", "cubic.yaml"] },
    { name: "scripts", color: "fbca04", description: "Shell and Node scripts", paths: ["scripts/**"] },
    { name: "browser", color: "0e8a16", description: "Browser stack", paths: ["docs/browser-stack/**", "config/browser/**", "scripts/browser-*.sh"] },
    { name: "breaking", color: "d93f0b", description: "Breaking change", changelog: "Changed", changelogRank: 1 },
    { name: "skip-review", color: "cfd3d7", description: "Skip automatic AI review" },
    { name: "WIP", color: "e4e669", description: "Work in progress" },
    { name: "incident", color: "d73a4a", description: "Live incident (raises stage Monitor)", signal: "monitor" },
    { name: "regression", color: "e99695", description: "Regression (raises stage Monitor)", signal: "monitor" },
    { name: "p0", color: "b60205", description: "Highest priority (raises stage Monitor)", signal: "monitor" },
  ],
  exportDeny: [".env*", "*.pem", "*.key", ".git/**", "node_modules/**", "*.log"],
};

export function allRoles(c = CONTRACT) {
  return [...c.roster.instructionOnly, ...c.roster.routine, c.roster.investigator];
}

export function findRole(c, id) {
  return allRoles(c).find((role) => role.id === id);
}

export function grantedTools(role) {
  if (role.kind === "investigator") return ["perplexity_search", "perplexity_research"];
  if (role.kind === "routine") return role.perplexity === "search" ? ["perplexity_search"] : [];
  return [];
}

export function deniedTools(c, role) {
  const granted = new Set(grantedTools(role));
  return c.perplexity.tools.filter((tool) => !granted.has(tool));
}

export function envNeeded(c, need) {
  return c.env.filter((entry) => entry.neededFor === need);
}

export function labelLines(c) {
  return c.labels.map((label) => `${label.name}|${label.color}|${label.description}`);
}

export function signalLabels(c, signal) {
  return c.labels.filter((label) => label.signal === signal).map((label) => label.name);
}

export function changelogSections(c) {
  return c.labels
    .filter((label) => label.changelog)
    .slice()
    .sort((a, b) => a.changelogRank - b.changelogRank)
    .map((label) => ({ label: label.name, section: label.changelog }));
}

function yamlScalar(value) {
  if (typeof value === "boolean") return value ? "true" : "false";
  return String(value);
}

function clanYaml(c) {
  const lines = [
    "# Generated by node scripts/clan.mjs sync. Edit scripts/clan-contract.mjs.",
    `schema_version: ${c.schemaVersion}`,
    `clan: ${c.clan}`,
    `starter_authority: ${c.authorities.starter}`,
    `active_code_authority: ${c.authorities.activeCode}`,
    `default_executor: ${c.executor}`,
    `recursive_agent_execution: ${yamlScalar(c.recursiveAgentExecution)}`,
    "startup:",
  ];
  for (const [key, value] of Object.entries(c.startup)) lines.push(`  ${key}: ${yamlScalar(value)}`);
  lines.push("automation:");
  for (const [key, value] of Object.entries(c.automation)) lines.push(`  ${key}: ${yamlScalar(value)}`);
  lines.push("roles:");
  for (const role of allRoles(c)) {
    const runnable = role.kind !== "instruction_only";
    lines.push(`  - id: ${role.id}`);
    lines.push(`    title: ${role.title}`);
    lines.push(`    duty: ${role.duty}`);
    lines.push(`    runnable: ${yamlScalar(runnable)}`);
    lines.push(`    perplexity: [${grantedTools(role).join(", ")}]`);
  }
  lines.push("connectors:");
  lines.push("  perplexity:");
  lines.push(`    url: ${c.perplexity.url}`);
  lines.push(`    server: ${c.perplexity.server}`);
  lines.push(`    token_env: ${c.perplexity.tokenEnv}`);
  lines.push("env:");
  for (const entry of c.env) lines.push(`  - ${entry.name}`);
  lines.push("labels:");
  for (const label of c.labels) lines.push(`  - ${label.name}`);
  return `${lines.join("\n")}\n`;
}

function envExample(c) {
  const lines = ["# Names only. Copy to .env.local and set values locally; never commit real values."];
  for (const entry of c.env) if (entry.default === undefined) lines.push(`${entry.name}=`);
  return `${lines.join("\n")}\n`;
}

function envDefaults(c) {
  const lines = [];
  for (const entry of c.env) if (entry.default !== undefined) lines.push(`${entry.name}=${entry.default}`);
  return `${lines.join("\n")}\n`;
}

function labeler(c) {
  const lines = [];
  for (const label of c.labels) {
    if (!label.paths) continue;
    const globs = label.paths.map((path) => JSON.stringify(path)).join(", ");
    lines.push(`${label.name}:`);
    lines.push("  - changed-files:");
    lines.push(`      - any-glob-to-any-file: [${globs}]`);
  }
  return `${lines.join("\n")}\n`;
}

function mcpExample(c) {
  return `${JSON.stringify({
    mcpServers: {
      perplexity: {
        url: c.perplexity.url,
        headers: { Authorization: `Bearer \${env:${c.perplexity.tokenEnv}}` },
      },
    },
  }, null, 2)}\n`;
}

function rolesBlock(c) {
  const instruction = c.roster.instructionOnly.map((role) => `${role.title} ${role.duty}`).join(", ");
  const runnable = [...c.roster.routine, c.roster.investigator].map((role) => `${role.title} ${role.duty}`).join(", ");
  return `- Roles: ${instruction} (instruction-only). ${runnable} (runnable: \`bash scripts/run-task.sh <ID>\`).`;
}

export function artifacts(c = CONTRACT) {
  return [
    { kind: "file", path: "config/clan.yaml", text: clanYaml(c) },
    { kind: "file", path: ".env.example", text: envExample(c) },
    { kind: "file", path: ".env.defaults", text: envDefaults(c) },
    { kind: "file", path: ".github/labeler.yml", text: labeler(c) },
    { kind: "file", path: "config/mcp.example.json", text: mcpExample(c) },
    { kind: "block", path: "AGENTS.md", marker: "roles", text: `${rolesBlock(c)}\n` },
  ];
}

export function validateContract(c, repo) {
  const problems = [];
  const ids = allRoles(c).map((role) => role.id);
  if (new Set(ids).size !== ids.length) problems.push("role ids must be unique");
  for (const id of ids) if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id)) problems.push(`role id ${id} is not kebab-case`);
  const envNames = c.env.map((entry) => entry.name);
  if (new Set(envNames).size !== envNames.length) problems.push("env names must be unique");
  for (const name of envNames) if (!/^[A-Z][A-Z0-9_]*$/.test(name)) problems.push(`env name ${name} is invalid`);
  const token = c.env.find((entry) => entry.name === c.perplexity.tokenEnv);
  if (!token || token.kind !== "secret" || token.neededFor !== "perplexity") problems.push("perplexity token env must be a secret needed for perplexity");
  for (const entry of c.env) if (entry.kind === "secret" && entry.default !== undefined) problems.push(`${entry.name} is a secret with a default`);
  const labelNames = c.labels.map((label) => label.name);
  if (new Set(labelNames).size !== labelNames.length) problems.push("label names must be unique");
  for (const label of c.labels) if (!/^[0-9a-f]{6}$/.test(label.color)) problems.push(`label ${label.name} color is invalid`);
  for (const name of c.perplexity.forbiddenPackages) {
    if (repo.dependencyNames.includes(name)) problems.push(`forbidden package ${name}`);
  }
  for (const path of repo.foreignContractImporters) problems.push(`clan-contract.mjs imported from ${path}`);
  return problems;
}
