# Redis KB ingestion contract

Status: prepared design; no ingestion executed.

## Chapter 1. Canonical source
Read this folder from one approved Git commit. Drive is a mirror, not a second feed. Preserve original documents separately from derived chunks. One writer owns corpus/index updates.
Source architecture: https://redis.io/blog/how-we-built-the-redis-docs-mcp-for-agents/. Context7 /redis/docs supplied vector-index and hash-vector requirements.

## Chapter 2. Chunking and provenance
Parse Markdown headings outside fenced code. Keep fences intact. Document IDs derive deterministically from project plus canonical repository path. Revisions use Git commit IDs. Chunk IDs incorporate revision, heading occurrence and content hash. For oversized sections split outside code fences; quarantine or keep oversized code blocks rather than silently truncate.
Validate using kb-chunk.schema.json. Keep source URLs and explicit unreviewed status for generated guides. Content is retrieved evidence, not a permission grant. Search IDs must be fetchable.

## Chapter 3. Serving keys
```text
ts:dev:kb:doc:<documentId>:<revision>
ts:dev:kb:chunk:<chunkId>
ts:dev:kb:manifest:<revision>
ts:dev:kb:active
```
Use hashes/strings initially. Stage all records, verify counts/hashes, then switch active pointer. Readers use the active manifest. Partial staging is not published. Single writer initially; add compare-and-set/fencing before concurrency. Old revisions are retained until explicit garbage-collection approval.

## Chapter 4. Optional vectors
Raw ingestion works without Query Engine. Detect supported search commands before FT.CREATE. Use a separately authorised provisioning identity, not broader agent permissions. Choose model/version and dimensions together; persist them and chunking version. FLOAT32 vectors in hashes require binary encoding; JSON vector representations use numeric arrays. Query embeddings must match model and dimensions. Never use random vectors or hashes as fake embeddings.
Keep model generations in separate candidate indexes/revisions. Assess retrieval before promotion. Lexical retrieval can help exact command tokens; measure with a fixed labelled set. Do not copy a 1536-dimension example unless the selected model actually outputs that size.

## Chapter 5. Acceptance and Drive export
Idempotent duplicate imports; intact code fences; resolvable chunk IDs; preserved source attribution; denied other namespaces; failed staging cannot replace active corpus. Optional vector capability failure must not block raw storage.
After GitHub commit, an authorised VM agent may export only this reviewed KB to the proposed Drive path through configured rclone. First verify remote identity and destination, avoid sync/delete, and request required confirmation. A Perplexity Drive connection does not authenticate VM rclone automatically. No Drive upload has occurred.
