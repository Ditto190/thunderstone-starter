# Browser Stack for Grok VM Bots — Plan, Budget, Changelog

Branch: `feat/browser-stack`. Scope: bootstrap shortlist items 1–5 from the browser-tooling research.

## Budget (credit-aware)
| Phase | Work | Budget | Status |
|---|---|---|---|
| 0 | Locate repo, read AGENTS.md/validate.sh | low | done |
| 1 | Plan + project files (this doc, routing, playbook schema) | low | done |
| 2 | Bootstrap scripts + MCP config (no heavy deps installed in CI) | medium | done |
| 3 | Validate (bash -n, JSON parse), push, PR; ShellCheck runs in CI | low | partial (ShellCheck pending) |
| 4 | Drive update (plan + changelog) | low | done |
| Deferred | Live VM smoke test, Rustwright benchmark, flag verification via Context7 | — | next agent |

Rule: if a phase overruns, stop coding and ship docs only.

## Shortlist → files
1. agent-browser controlling CloakBrowser sidecar → `scripts/browser-up.sh`, `scripts/browser-mcp.sh`
2. Scrapling MCP + Firecrawl read path → `config/browser/mcp.example.json`
3. Rustwright MCP (alt, opt-in) → `config/browser/mcp.example.json` (add a `rustwright` entry yourself and enable it in your MCP client UI; no entry ships)
4. Hanzi-style per-domain skills (method only, no PolyForm code) → `config/browser/playbooks/`
5. CUA last → `docs/browser-stack/ROUTING.md`

## Runbook (Chief Thunder-Terminal)
```bash
bash scripts/browser-up.sh        # CloakBrowser on 127.0.0.1:9222, profiles in .state/browser
bash scripts/browser-doctor.sh    # checks docker, CDP, agent-browser, scrapling
cp config/browser/mcp.example.json .cursor/mcp.json   # gitignored; secrets via env-run
```

## Guardrails
CDP loopback only. One VM/profile per bot. Secrets via `scripts/env-run.mjs`, never in config. Human approval is required BEFORE executing MFA, posts, purchases, uploads, JS eval, account changes or legal acceptance, regardless of routing tier. Respect site terms, robots and rate limits.

## Open verification (next agent)
- Verified 2026-10-10 (Context7 and upstream README): `agent-browser mcp --tools` profiles are core, network, state, debug, tabs, react, mobile, all; `cloakhq/cloakbrowser` with `cloakserve --headless=false --idle-timeout` matches `scripts/browser-up.sh`. Note: the agent-browser npm package declares node >= 24; bootstrap installs Node 22, so expect an engines warning.
- Confirm Rustwright MCP binary name; currently placeholder `rustwright-mcp`.
- CloakBrowser binary licence/concurrency limits before scaling beyond pilot.

## Changelog
- 2026-10-10: Initial plan, routing policy, playbook schema, sidecar/MCP bootstrap scripts, doctor check.
