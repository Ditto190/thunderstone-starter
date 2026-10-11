---
name: perplexity-search-router
description: Route current-web research through the hosted Perplexity MCP. Use when a runnable clan role needs a sourced fact that is not in the repo or the Drive knowledge base.
---

# Perplexity search router

The connector is the hosted MCP server at `https://api.perplexity.ai/mcp`. One server. No Node SDK and no local stdio server in this repo.

1. Read the brief, project files, and the Drive knowledge base first.
2. Use Context7 for library documentation and GitHub for repository truth.
3. Routine roles (`cursor-hammer`, `watcher-of-broken-things`) may call `perplexity_search` only.
4. `chief-investigator` may also call `perplexity_research`.
5. Do not call `perplexity_ask` or `perplexity_reason`.
6. Keep source URLs. Separate those sources from synthesis.
7. Never place `PERPLEXITY_API_KEY` in a prompt, a committed file, or a report.
8. Ask before publishing, commenting, pushing, or changing remote state.
