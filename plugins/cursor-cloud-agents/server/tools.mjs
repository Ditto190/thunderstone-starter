// Tool definitions and handlers. Each handler maps to one documented Cloud Agents v1 REST call.
// Guards: launch_agent and cancel need confirm:true, per-session launch cap, no delete or archiving tool,
// autoCreatePR defaults to false, and nothing here ever schedules work (poll-only, no timers).
import { ApiError, createClient } from "./client.mjs";
import { redact, redactDeep } from "./redact.mjs";

export const DEFAULT_MAX_LAUNCHES = 3;
const HARD_MAX_LAUNCHES = 20;
const MAX_PROMPT_CHARS = 100000;
const MAX_NAME_CHARS = 100;
const MAX_RESULT_CHARS = 20000;
const ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const TERMINAL_RUN_STATUSES = new Set(["FINISHED", "ERROR", "CANCELLED", "EXPIRED"]);

export class ToolInputError extends Error {
  constructor(message, code = "invalid_input", extra = {}) {
    super(message);
    this.name = "ToolInputError";
    this.code = code;
    this.extra = extra;
  }
}

/** null means unset (allow every repo). Empty or whitespace-only is the same as unset. */
export function parseAllowedRepoPrefixes(env = process.env) {
  const raw = env.CURSOR_CLOUD_AGENTS_ALLOWED_REPOS;
  if (raw === undefined || String(raw).trim() === "") return null;
  const prefixes = String(raw)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return prefixes.length ? prefixes : null;
}

/** Origin plus decoded path segments. null when the value is not a usable repo URL. */
function repoParts(raw) {
  let u;
  try {
    u = new URL(String(raw).trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:" && u.protocol !== "http:") return null;
  if (u.username || u.password) return null;
  const hostAt = String(raw).indexOf(u.host);
  if (hostAt < 0) return null;
  const rawPath = String(raw).slice(hostAt + u.host.length).split(/[?#]/)[0];
  const segments = rawPath.split("/").filter((s) => s !== "");
  let decoded;
  try {
    decoded = segments.map((s) => decodeURIComponent(s));
  } catch {
    return null;
  }
  if (decoded.some((s) => s === "." || s === ".." || s.includes("/") || s.includes("\\"))) return null;
  return { origin: u.origin, segments: decoded };
}

function repoMatchesPrefix(repoUrl, prefix) {
  const repo = repoParts(repoUrl);
  const allow = repoParts(prefix);
  if (!repo || !allow || repo.origin !== allow.origin) return false;
  if (repo.segments.length < allow.segments.length) return false;
  return allow.segments.every((seg, i) => repo.segments[i] === seg);
}

export function assertRepoAllowed(repoUrl, env = process.env) {
  const prefixes = parseAllowedRepoPrefixes(env);
  if (!prefixes) return;
  if (prefixes.some((prefix) => repoMatchesPrefix(repoUrl, prefix))) return;
  throw new ToolInputError(
    "repoUrl is outside CURSOR_CLOUD_AGENTS_ALLOWED_REPOS. No request was sent.",
    "repo_not_allowed",
  );
}

export function resolveLaunchCap(env = process.env) {
  const raw = env.CURSOR_MAX_LAUNCHES_PER_SESSION;
  if (raw === undefined || raw === "") return DEFAULT_MAX_LAUNCHES;
  if (!/^\d{1,3}$/.test(String(raw).trim())) return DEFAULT_MAX_LAUNCHES;
  const n = Number.parseInt(raw, 10);
  return n <= HARD_MAX_LAUNCHES ? n : DEFAULT_MAX_LAUNCHES;
}

export function nextPollSeconds(runStatus, agentStatus) {
  if (runStatus && TERMINAL_RUN_STATUSES.has(runStatus)) return null;
  if (runStatus === "CREATING") return 5;
  if (runStatus === "RUNNING") return 20;
  if (agentStatus === "ACTIVE") return 10;
  return null;
}

const asText = (v, field, { required = false, max } = {}) => {
  if (v === undefined || v === null || v === "") {
    if (required) throw new ToolInputError(`"${field}" is required.`);
    return undefined;
  }
  if (typeof v !== "string") throw new ToolInputError(`"${field}" must be a string.`);
  const t = v.trim();
  if (required && !t) throw new ToolInputError(`"${field}" must not be empty.`);
  if (max && t.length > max) throw new ToolInputError(`"${field}" is longer than ${max} characters.`);
  return t || undefined;
};

const asId = (v, field) => {
  const id = asText(v, field, { required: true });
  if (!ID_PATTERN.test(id)) throw new ToolInputError(`"${field}" is not a valid identifier.`);
  return id;
};

const asUrl = (v, field) => {
  const t = asText(v, field);
  if (t === undefined) return undefined;
  let u;
  try {
    u = new URL(t);
  } catch {
    throw new ToolInputError(`"${field}" must be an http(s) URL.`);
  }
  if (u.protocol !== "https:" && u.protocol !== "http:") throw new ToolInputError(`"${field}" must be an http(s) URL.`);
  if (u.username || u.password) throw new ToolInputError(`"${field}" must not contain credentials.`);
  return t;
};

const asBool = (v, field, dflt) => {
  if (v === undefined || v === null) return dflt;
  if (typeof v !== "boolean") throw new ToolInputError(`"${field}" must be a boolean.`);
  return v;
};

const asMode = (v) => {
  if (v === undefined || v === null || v === "") return undefined;
  if (v !== "agent" && v !== "plan") throw new ToolInputError('"mode" must be "agent" or "plan".');
  return v;
};

function requireConfirm(args, action) {
  if (args.confirm !== true) {
    throw new ToolInputError(
      `${action} needs explicit confirmation. Ask DT (or the requester) to approve, then call again with confirm: true.`,
      "confirmation_required",
      { action },
    );
  }
}

function truncate(text, max = MAX_RESULT_CHARS) {
  if (typeof text !== "string" || text.length <= max) return { text, truncated: false };
  return { text: text.slice(0, max), truncated: true };
}

const pickAgent = (a = {}) => ({
  id: a.id,
  name: a.name,
  status: a.status,
  url: a.url,
  env: a.env,
  repos: a.repos,
  workOnCurrentBranch: a.workOnCurrentBranch,
  autoCreatePR: a.autoCreatePR,
  latestRunId: a.latestRunId,
  createdAt: a.createdAt,
  updatedAt: a.updatedAt,
});

function pickRun(r) {
  if (!r) return null;
  const out = { id: r.id, status: r.status, createdAt: r.createdAt, updatedAt: r.updatedAt };
  if (r.durationMs !== undefined) out.durationMs = r.durationMs;
  if (typeof r.result === "string") {
    const { text, truncated } = truncate(r.result);
    out.result = text;
    if (truncated) out.resultTruncated = true;
  }
  if (r.git) out.git = r.git;
  return out;
}

const idProp = { type: "string", description: "Cloud agent id, e.g. bc-00000000-0000-0000-0000-000000000001." };
const confirmProp = {
  type: "boolean",
  description: "Must be true. Set it only after the requester has approved this exact action.",
};

export const TOOL_DEFINITIONS = [
  {
    name: "launch_agent",
    title: "Launch a Cloud Agent",
    description:
      "Create a Cursor Cloud Agent on a repository and enqueue its first run. Returns immediately with agentId and runId; poll get_status. Spends Cursor quota and the agent may push a new cursor/ branch, so it needs confirm:true and is capped per MCP session. No PR is opened unless autoCreatePR is true.",
    inputSchema: {
      type: "object",
      properties: {
        prompt: { type: "string", description: "Instruction for the agent." },
        repoUrl: {
          type: "string",
          description: "Repository URL on GitHub, GitLab or another connected provider, e.g. https://github.com/org/repo.",
        },
        startingRef: { type: "string", description: "Branch name or commit SHA to start from (default branch if omitted)." },
        prUrl: { type: "string", description: "Existing PR/MR URL to work on (repoUrl is still required)." },
        model: { type: "string", description: "Optional model id from GET /v1/models. Omit for the account default." },
        name: { type: "string", description: "Optional display name, max 100 characters." },
        mode: { type: "string", enum: ["agent", "plan"], description: "agent implements; plan drafts a plan first." },
        autoCreatePR: { type: "boolean", description: "Open a PR when the run completes. Default false." },
        confirm: confirmProp,
      },
      required: ["prompt", "repoUrl", "confirm"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
  },
  {
    name: "get_status",
    title: "Get agent and latest run status",
    description:
      "Read an agent (GET /v1/agents/{id}) and its latest run (or a given runId). Includes nextPollSeconds: how long to wait before polling again (null when the run is finished). Read-only; this server never polls on its own.",
    inputSchema: {
      type: "object",
      properties: { agentId: idProp, runId: { type: "string", description: "Optional run id. Defaults to the agent's latest run." } },
      required: ["agentId"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, openWorldHint: true },
  },
  {
    name: "followup",
    title: "Send a follow-up prompt",
    description:
      "Create a new run on an existing agent (POST /v1/agents/{id}/runs). If a run is still CREATING or RUNNING the API answers 409 agent_busy; this tool returns that as a structured, retryable error.",
    inputSchema: {
      type: "object",
      properties: {
        agentId: idProp,
        prompt: { type: "string", description: "Follow-up instruction." },
        mode: { type: "string", enum: ["agent", "plan"], description: "Optional mode override for this run." },
      },
      required: ["agentId", "prompt"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
  },
  {
    name: "list_agents",
    title: "List agents",
    description: "List the caller's agents, newest first (GET /v1/agents). Pass nextCursor back as cursor for the next page.",
    inputSchema: {
      type: "object",
      properties: {
        limit: { type: "integer", minimum: 1, maximum: 100, description: "Page size, default 20." },
        cursor: { type: "string", description: "nextCursor from a previous page." },
        prUrl: { type: "string", description: "Only agents linked to this PR/MR URL." },
        includeArchived: { type: "boolean", description: "Include archived agents (API default is true)." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, openWorldHint: true },
  },
  {
    name: "cancel",
    title: "Cancel a run",
    description:
      "Cancel the active run (POST /v1/agents/{id}/runs/{runId}/cancel). Cancellation is terminal for that run. Needs confirm:true. Uses the agent's latest run when runId is omitted. 409 run_not_cancellable is returned as a structured error.",
    inputSchema: {
      type: "object",
      properties: { agentId: idProp, runId: { type: "string", description: "Run to cancel. Defaults to the latest run." }, confirm: confirmProp },
      required: ["agentId", "confirm"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true },
  },
  {
    name: "get_artifacts",
    title: "List artifacts or get a download link",
    description:
      "List an agent's artifacts (GET /v1/agents/{id}/artifacts). With path set to one of the listed paths, returns a temporary presigned download URL (about 15 minutes). Treat that URL as sensitive and do not paste it into chats.",
    inputSchema: {
      type: "object",
      properties: {
        agentId: idProp,
        path: { type: "string", description: "Optional artifact path from the list, e.g. artifacts/screenshot.png." },
      },
      required: ["agentId"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, openWorldHint: true },
  },
];

function toErrorPayload(err, env) {
  if (err instanceof ToolInputError) {
    return { code: err.code, message: err.message, ...err.extra };
  }
  if (err instanceof ApiError) {
    const retryable = err.status === 429 || (err.status !== null && err.status >= 500) || err.code === "timeout" || err.code === "network_error";
    const payload = { code: err.code, status: err.status, message: err.message, retryable };
    if (err.retryAfterSeconds !== null) payload.retryAfterSeconds = err.retryAfterSeconds;
    if (err.hint) payload.hint = err.hint;
    if (err.extra) Object.assign(payload, err.extra);
    return payload;
  }
  return { code: "internal_error", message: redact(String(err?.message ?? err), env), retryable: false };
}

export function createToolbox({ env = process.env, client = createClient({ env }) } = {}) {
  const cap = resolveLaunchCap(env);
  let launchesUsed = 0;

  const handlers = {
    async launch_agent(args) {
      const prompt = asText(args.prompt, "prompt", { required: true, max: MAX_PROMPT_CHARS });
      const repoUrl = asUrl(args.repoUrl, "repoUrl");
      if (!repoUrl) throw new ToolInputError('"repoUrl" is required.');
      const startingRef = asText(args.startingRef, "startingRef", { max: 255 });
      const prUrl = asUrl(args.prUrl, "prUrl");
      const model = asText(args.model, "model", { max: 128 });
      const name = asText(args.name, "name", { max: MAX_NAME_CHARS });
      const mode = asMode(args.mode);
      const autoCreatePR = asBool(args.autoCreatePR, "autoCreatePR", false);
      assertRepoAllowed(repoUrl, env);
      requireConfirm(args, "launch_agent");
      if (launchesUsed >= cap) {
        throw new ToolInputError(
          `Launch cap reached: ${launchesUsed} of ${cap} launches used in this MCP session. Restart the server, or raise CURSOR_MAX_LAUNCHES_PER_SESSION (max ${HARD_MAX_LAUNCHES}), only with DT's approval.`,
          "launch_cap_reached",
          { launchesUsed, launchCap: cap },
        );
      }
      const repo = { url: repoUrl };
      if (startingRef) repo.startingRef = startingRef;
      if (prUrl) repo.prUrl = prUrl;
      const body = { prompt: { text: prompt }, repos: [repo], autoCreatePR, workOnCurrentBranch: false };
      if (model) body.model = { id: model };
      if (name) body.name = name;
      if (mode) body.mode = mode;

      launchesUsed += 1; // reserve before the call so a slow request cannot be raced past the cap
      let res;
      try {
        res = await client.post("/v1/agents", body);
      } catch (err) {
        // A definite 4xx means nothing was created, so give the slot back. Timeouts and 5xx keep it.
        if (err instanceof ApiError && err.status !== null && err.status >= 400 && err.status < 500) launchesUsed -= 1;
        throw err;
      }
      const agent = res.agent ?? {};
      const run = res.run ?? {};
      return {
        agentId: agent.id,
        runId: run.id ?? agent.latestRunId,
        agentStatus: agent.status,
        runStatus: run.status,
        url: agent.url,
        autoCreatePR,
        nextPollSeconds: nextPollSeconds(run.status, agent.status) ?? 5,
        launchesUsed,
        launchesRemaining: Math.max(cap - launchesUsed, 0),
      };
    },

    async get_status(args) {
      const agentId = asId(args.agentId, "agentId");
      const runIdArg = args.runId === undefined || args.runId === null || args.runId === "" ? undefined : asId(args.runId, "runId");
      const agent = await client.get(`/v1/agents/${encodeURIComponent(agentId)}`);
      const runId = runIdArg ?? agent.latestRunId;
      let run = null;
      let runError;
      if (runId) {
        try {
          run = await client.get(`/v1/agents/${encodeURIComponent(agentId)}/runs/${encodeURIComponent(runId)}`);
        } catch (err) {
          runError = toErrorPayload(err, env);
        }
      }
      const out = {
        agent: pickAgent(agent),
        run: pickRun(run),
        terminal: run ? TERMINAL_RUN_STATUSES.has(run.status) : false,
        nextPollSeconds: run ? nextPollSeconds(run.status, agent.status) : nextPollSeconds(undefined, agent.status),
      };
      if (runError) out.runError = runError;
      return out;
    },

    async followup(args) {
      const agentId = asId(args.agentId, "agentId");
      const prompt = asText(args.prompt, "prompt", { required: true, max: MAX_PROMPT_CHARS });
      const mode = asMode(args.mode);
      const body = { prompt: { text: prompt } };
      if (mode) body.mode = mode;
      let res;
      try {
        res = await client.post(`/v1/agents/${encodeURIComponent(agentId)}/runs`, body);
      } catch (err) {
        if (err instanceof ApiError && err.status === 409 && (err.code === "agent_busy" || err.code === "conflict")) {
          const busy = new ApiError({
            status: 409,
            code: "agent_busy",
            message: "The agent already has a run in progress (CREATING or RUNNING). Only one run can be active per agent.",
          });
          busy.hint = "Poll get_status until the run is terminal, or cancel the active run (needs confirm:true), then retry followup.";
          busy.extra = { retryable: true, nextPollSeconds: 15 };
          throw busy;
        }
        throw err;
      }
      const run = res.run ?? {};
      return { agentId, runId: run.id, runStatus: run.status, nextPollSeconds: nextPollSeconds(run.status) ?? 5 };
    },

    async list_agents(args) {
      let limit;
      if (args.limit !== undefined && args.limit !== null) {
        if (!Number.isInteger(args.limit) || args.limit < 1 || args.limit > 100) throw new ToolInputError('"limit" must be an integer from 1 to 100.');
        limit = args.limit;
      }
      const cursor = asText(args.cursor, "cursor", { max: 512 });
      const prUrl = asUrl(args.prUrl, "prUrl");
      const includeArchived = asBool(args.includeArchived, "includeArchived", undefined);
      const res = await client.get("/v1/agents", {
        limit,
        cursor,
        prUrl,
        includeArchived: includeArchived === undefined ? undefined : String(includeArchived),
      });
      const out = { items: Array.isArray(res.items) ? res.items : [] };
      if (res.nextCursor) out.nextCursor = res.nextCursor; // absent means no more pages
      return out;
    },

    async cancel(args) {
      const agentId = asId(args.agentId, "agentId");
      const runIdArg = args.runId === undefined || args.runId === null || args.runId === "" ? undefined : asId(args.runId, "runId");
      requireConfirm(args, "cancel");
      let runId = runIdArg;
      if (!runId) {
        const agent = await client.get(`/v1/agents/${encodeURIComponent(agentId)}`);
        runId = agent.latestRunId;
        if (!runId) throw new ToolInputError("The agent has no run to cancel.", "no_run");
      }
      try {
        const res = await client.post(`/v1/agents/${encodeURIComponent(agentId)}/runs/${encodeURIComponent(runId)}/cancel`);
        return { agentId, runId: res.id ?? runId, cancelled: true };
      } catch (err) {
        if (err instanceof ApiError && err.status === 409) {
          const e = new ApiError({
            status: 409,
            code: "run_not_cancellable",
            message: "The run is already in a terminal state or was never active, so it cannot be cancelled.",
          });
          e.hint = "Call get_status to see the run's final state.";
          e.extra = { retryable: false };
          throw e;
        }
        throw err;
      }
    },

    async get_artifacts(args) {
      const agentId = asId(args.agentId, "agentId");
      const path = asText(args.path, "path", { max: 1024 });
      if (path === undefined) {
        const res = await client.get(`/v1/agents/${encodeURIComponent(agentId)}/artifacts`);
        return { agentId, items: Array.isArray(res.items) ? res.items : [] };
      }
      if (!path.startsWith("artifacts/") || path.split("/").includes("..") || path.includes("\\")) {
        throw new ToolInputError('"path" must be a relative path under artifacts/ as returned by the list.');
      }
      const res = await client.get(`/v1/agents/${encodeURIComponent(agentId)}/artifacts/download`, { path });
      return {
        agentId,
        path,
        url: res.url,
        expiresAt: res.expiresAt,
        note: "Temporary presigned link (about 15 minutes). Do not share it outside this task.",
      };
    },
  };

  async function call(name, args) {
    const handler = handlers[name];
    if (!handler) return { unknownTool: true };
    const input = args && typeof args === "object" && !Array.isArray(args) ? args : {};
    try {
      const data = redactDeep(await handler(input), env);
      return { isError: false, data };
    } catch (err) {
      return { isError: true, data: redactDeep({ error: toErrorPayload(err, env) }, env) };
    }
  }

  return { definitions: TOOL_DEFINITIONS, call, state: () => ({ launchesUsed, launchCap: cap }) };
}
