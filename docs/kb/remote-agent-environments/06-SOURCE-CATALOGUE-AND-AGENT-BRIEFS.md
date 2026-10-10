# Source catalogue and drop-in agent briefs

## Chapter 1. Cursor runtime
```text
Fetch https://cursor.com/docs, https://cursor.com/docs/cloud-agent/capabilities, https://cursor.com/docs/cloud-agent/automations, https://cursor.com/docs/cloud-agent/self-hosted/my-machines and https://cursor.com/docs/cli/reference/parameters.
Distinguish hosted Cloud Agent, shared Grok computer and self-hosted worker. Inspect existing registration before adding one. Determine the actual meaning of grok-bot-vm-347906125#/workspace. Extract current targeting/authentication and recovery mechanisms; do not invent IDs or API endpoints.
```

## Chapter 2. Skills, plugins, MCP and SDK
```text
Fetch https://cursor.com/docs/skills, https://cursor.com/docs/subagents, https://cursor.com/docs/hooks, https://cursor.com/docs/rules, https://cursor.com/docs/plugins, https://cursor.com/docs/mcp, https://cursor.com/docs/cli/mcp and https://cursor.com/docs/mcp/install-links.
Inspect https://github.com/cursor/plugins and https://github.com/cursor/cookbook; use https://cursor.com/docs/sdk/typescript for API shape.
Select minimal project-scoped integrations, cite exact paths/commits and verify schemas against installed versions. Compare SDK/DAG examples before custom dispatch. Separate local and Cloud transport/authentication compatibility. Do not bulk-install.
```

## Chapter 3. Poteto, review and canvases
```text
Inspect https://github.com/cursor/plugins/blob/main/pstack/README.md and https://github.com/cursor/plugins/blob/main/pstack/skills/setup-pstack/SKILL.md.
Catalogue selected families in cursor/plugins: cursor-sdk, cursor-team-kit, orchestrate, continual-learning, docs-canvas and pr-review-canvas.
Read selected skill leaves and dependencies in full. Discover available models rather than copying model names blindly. One controller owns each task. Compare https://github.com/obra/superpowers for sequential implementation and independent parallel work. Promote lessons through reviewed tests/evals. Tie canvases to issue/PR IDs.
```

## Chapter 4. Cursor-hosted Grok Bot
```text
Fetch https://cursor.com/docs/grok-bot, https://cursor.com/docs/grok-bot/get-started, https://cursor.com/docs/grok-bot/work, https://cursor.com/docs/grok-bot/teams, https://cursor.com/docs/grok-bot/settings, https://cursor.com/docs/grok-bot/computers, https://cursor.com/docs/grok-bot/security-faq and https://cursor.com/docs/grok-bot/deployment.
Establish shared files/processes, connector policy, skills/routines and delegation semantics. Account-tier restrictions matter. Admin recreate/terminate is destructive and separate. xAI inference SDK is not proof of a VM-control API.
```

## Chapter 5. xAI APIs and coding harness
```text
Fetch https://docs.x.ai/overview, https://docs.x.ai/developers/docs-mcp, https://docs.x.ai/developers/tools/remote-mcp and https://docs.x.ai/build/overview.
Inspect https://github.com/xai-org/xai-sdk-python, https://github.com/xai-org/xai-sdk-ts, https://github.com/xai-org/xai-cookbook, https://github.com/xai-org/grok-build and https://github.com/xai-org/xai-proto.
Distinguish docs, paid inference, coding harness, ACP and hosted Bot control. Extract auth requirements without unnecessary inference dependencies. Confirm private-network restrictions before model-hosted MCP connections.
```

## Chapter 6. Provenance limits
Current preparation checked Redis ingestion/index guidance through Context7 /redis/docs and Redis Docs MCP architecture through Firecrawl. Broader links were captured in prior research and must be fetched before exact code extraction. Guides are original adaptations, not verbatim repository exports. Requested bdk-framework-map, bdk-evals and bdk-github sources remain unverified. https://github.com/broneq/bdk is a separate Broneq Dev Kit lead, not established as Cursor BDK. Never substitute unrelated Bitcoin/Symphony kits.
