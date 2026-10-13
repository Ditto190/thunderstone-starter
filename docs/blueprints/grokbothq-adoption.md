# Blueprint: GrokBot HQ adoption

Status: PROPOSED (review required).

## Repos
- Writable operational fork: ModifyMe-Org/grokbothq (origin)
- Original: V-harshith/grokbothq (upstream, fetch only)

## Warning
The inherited GrokBot AGENTS.md names V-harshith/grokbothq and says pushes to `main` auto-deploy via Vercel. Verify the Vercel project binding for the fork before any unattended write. Never push to `main`.

## Low-bloat rule
Do not copy Matrix or Thunderstone config into the GrokBot repo. Keep the following outside it (Drive or Matrix home):
- an ops skill that restates its hard rules (content only in `content/*.json`, verify every x.ai/bot link, never fabricate, PR only, no bare @handles in GitHub text)
- agent transcripts, browser profiles, tokens, schedules
Only the existing repo AGENTS.md, tests and CI travel with clones.

## Division of labour
- GitHub Actions: deterministic scheduled work already scripted (expire featured, metrics, IndexNow, build). Do not duplicate it in Matrix.
- Matrix/agents: link verification in a browser, submission review, upstream sync, editorial research.

## Task isolation
One worktree + branch per task, for example `ops/submission-<id>` or `ops/upstream-sync`. Roles map to Thunderstone roles in `config/blueprints/grokbothq.yaml`.
