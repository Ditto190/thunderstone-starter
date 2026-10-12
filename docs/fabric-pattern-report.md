# Fabric-pattern mapping (Thunderstone agent runtime)

Research anchor: [pplx-garden key concepts](https://deepwiki.com/perplexityai/pplx-garden/1.2-key-concepts).

| Fabric-style idea | Thunderstone implementation |
| --- | --- |
| Task descriptor | `examples/agent-runtime/task.json` |
| Content-addressed artifacts | SHA-256 on output paths in receipts |
| Pinned / pooled routing | `routing`, `workerPool`, `pinnedWorker` |
| Dispatch vs completion | `lease` vs `submit` / `validate` / `accept` |
| Aggregated gates | `gates[]` commands in `validate` |
| Lease fencing | `attemptId` + expiry on `lease` |

RDMA and GPU fabric transports are out of scope for agent orchestration in this repo.
