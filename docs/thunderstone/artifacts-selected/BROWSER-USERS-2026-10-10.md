# Cloak browser: who can and will use it (EA assessment, 2026-10-10 Sydney)

## DT's standing comments (recorded verbatim in intent)
- Market Index is just one routine of many; do not build the browser plan around it.
- The cloak browser (CloakBrowser CDP on 127.0.0.1:9222, plus agent-browser and Scrapling) is NOT used by orchestrators at first.
- First users: Cursor and other agents/tools, and Grok Bots, via headless CLI.
- Orchestrators (Chief Thunderstone, Grok Bot) step in only to guide, unblock, or handle multiple windows.
- Source: DT, chat with Executive Assistant, 2026-10-10 (t19u). Also saved in shared user memory.

## Assessment (from each agent's profile; availability from BROWSER-STACK-AVAILABILITY-2026-10-10.md)
| Agent | Group | Use it? | Why / how |
|---|---|---|---|
| Cursor-Runner | BUILD | YES, primary operator | Runs real CLI on the VM; owns `agent-browser --cdp http://127.0.0.1:9222`, Scrapling, start/stop scripts, evidence in artifacts/. |
| SWE | BUILD | YES | UI/E2E checks of PRs, reproducing prod/web issues; via Chief brief, runs CLI itself. |
| Senior Developer | BUILD | YES, via brief | Vibecoding/E2E verification of web builds; heavy work goes to Runner per its own rules. |
| Researcher | KNOWLEDGE | YES, likely heaviest user | Open-web and LinkedIn research, tool evals. Logged-in sites need DT's human handoff. |
| Executive Assistant | ADMIN | YES, light | Services with no connector (portals, forms); via headless CLI from a worker, never a bot-wide login. |
| Lingxi's Engineer Bot, Nightly Audit Engineer | BUILD | Only if a brief needs it | Work via Runner briefs; no direct browser need today. |
| Git-Scout, Chief Lorekeeper, Projects Manager | CONTROL/KNOWLEDGE/PROJECTS | NO | Read-only gates and board/context work; connectors and gh cover it. |
| Tradbot | ADMIN | NO | Profile says connectors/files directly, no workers; personal lane. |
| tinkabot, dr eggbot | PROJECTS | NO (tinkabot: maybe later to prove a scraped data shape) | API/plugin and bot design work. |
| Chief Thunderstone, Grok Bot | orchestrators | STEP-IN ONLY | Guide, unblock, or coordinate multiple windows/profiles. |

## Rules to carry (from docs/browser-stack/ROUTING.md and PLAN.md)
- Escalate tiers in order: Firecrawl, Scrapling HTTP, Scrapling stealth, agent-browser via CloakBrowser, screenshot annotate, CUA, human.
- One profile per bot under `.state/browser/profiles`; CDP stays on loopback.
- DT approval BEFORE MFA, posts, purchases, uploads, JS eval, account changes, legal acceptance.
- Respect site terms, robots, rate limits; do not use it to defeat bot checks on a site without DT's say.
- Sidecar does not survive a reboot; stop with `~/.local/share/ts-browser/stop-cloakserve.sh`.

## Open items
- browser-doctor.sh needs a non-docker mode to go green (docker is unavailable here).
- v154 needs a free GitHub sign-in licence key: DT's call.
- Playbooks dir has only the schema; first per-domain playbooks should come from real jobs, not Market Index.
