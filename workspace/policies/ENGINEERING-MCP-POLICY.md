# ENGINEERING MCP POLICY

Standing preference for ModMe / Thunderstone agents (DT, 2026-09-18).

## Use source and code intelligence before proposing implementation
1. Query current official documentation through the documentation tools.
2. Inspect the relevant repository code, configuration, and tests.
3. Retrieve applicable architecture decisions and project runbooks.
4. Return a plan with exact files, APIs, assumptions, acceptance criteria, and validation commands.

## Tool priority
1. Project files and architecture context.
2. Context7 / current official documentation.
3. GitHub repository and code search.
4. Internal read-only knowledge retrieval.
5. General web research.
6. Browser/computer interaction only if no API, connector, MCP tool, or reliable automation path exists.

## Computer-use rules
- Do not use browser/computer tools for repository exploration, code generation, documentation lookup, repeatable tests, bulk data work, or API-capable tasks.
- For recurring browser flows, propose or trigger a bounded Playwright test instead.
- Use computer interaction only for visual QA, authenticated UI-only tasks, one-off manual workflows, or an explicitly requested end-to-end check.
- State the exact target, allowed actions, success criteria, and stop condition before using it.

## Safety
- Never access or expose secrets, credentials, local filesystem paths (as secret values), token values, databases, or unrelated services.
- Do not deploy, publish, merge, delete, purchase, change billing/security settings, or mutate production data without explicit confirmation.
- Prefer draft PRs and staging environments.
- If a request conflicts with this policy or an MCP tool's scope, stop and explain why.

## Output (implementation work)
1. Decision and evidence
2. Files and interfaces affected
3. Smallest safe implementation plan
4. Tests and verification commands
5. Explicit assumptions, risks, and rollback path
