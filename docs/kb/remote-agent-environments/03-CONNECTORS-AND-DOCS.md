# Connectors and documentation

## Chapter 1. Official Redis docs
Source: https://redis.io/blog/how-we-built-the-redis-docs-mcp-for-agents/
```text
Name: redis-docs
URL: https://redis.io/mcp
Authentication: none
Tools: search(query), fetch(id), ask(question)
Purpose: public read-only documentation, not your database
```
Start with search, fetch returned IDs, use ask for multi-area synthesis. Test actual discovery and one lookup.

## Chapter 2. xAI docs and Context7
Sources: https://docs.x.ai/developers/docs-mcp and https://context7.com/docs/clients/cursor
```text
Name: xai-docs
URL: https://docs.x.ai/api/mcp
Transport: Streamable HTTP
Authentication: none shown in official examples
Tools: list_doc_pages, get_doc_page, search_docs
```
```text
Name: context7
URL: https://mcp.context7.com/mcp
Authentication: API key in protected client settings; verify header against current client guide
Interactive OAuth alternative: https://mcp.context7.com/mcp/oauth
Usage: resolve-library-id before query-docs
Libraries discovered: /websites/cursor, /websites/cursor_cli, /cursor/plugins, /cursor/cookbook, /websites/cursor_api, /redis/docs
```
Merge documentation configuration, never replace existing servers:
```json
{"mcpServers":{"redis-docs":{"url":"https://redis.io/mcp"},"xai-docs":{"url":"https://docs.x.ai/api/mcp"}}}
```
Source CLI commands: https://cursor.com/docs/cli/mcp
```bash
agent mcp list
agent mcp list-tools redis-docs
agent mcp list-tools xai-docs
```

## Chapter 3. Local Redis data MCP
Sources: https://github.com/redis/mcp-redis and https://redis.io/docs/latest/integrate/redis-mcp/
Inspected README documents stdio, not a verified hosted remote endpoint. Current README displays Python 3.14+; inspect chosen release requirements. Install uv through official guidance only if absent and authorised. Select an exact package version rather than blindly running latest.
```bash
uvx --from redis-mcp-server@VERIFIED_VERSION redis-mcp-server --help
```
Use a protected launcher that reads REDIS_PWD from the private credential file, exports REDIS_HOST=127.0.0.1, REDIS_PORT=6380 and REDIS_USERNAME=thunderstone, then executes the pinned package with host/port/username. Never pass a password URI in process arguments or repository JSON. Client starts the server over stdio; inspect actual tool names before using them.

## Chapter 4. Remote data connector remains a separate deployment
```text
Proposed: thunderstone-state
URL: UNSET
Transport: authenticated HTTPS Streamable HTTP
Tools: get_project_status, get_task, read_run_events, submit_task, record_artifact, request_run_cancel
Controls: schema validation, project scope, quotas, audit and idempotency
```
A redis:// URI or GitHub repository is not a remote MCP endpoint. Do not publish arbitrary Redis commands. Documentation connectors, data connectors and VM tools have different permissions and purposes.
