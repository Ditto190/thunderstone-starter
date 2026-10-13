---
type: inbox-entry
kind: new-feature-review
title: Matrix OS pilot + GrokBot HQ adoption
status: needs-review
created: 2026-10-10
requested_by: Ditto190
github_pr: see PR on Ditto190/thunderstone-starter, branch blueprint/matrix-os-grokbothq
target_roles: [chief-of-chiefs, thunder-terminal, watcher-of-broken-things, keeper-of-stone-tablets]
---

# New feature for review: Matrix OS + GrokBot HQ

## Ask
Review the two blueprints, decide go/no-go on a 2-week Matrix OS pilot, and confirm the GrokBot HQ preflight items.

## Summary
- Matrix OS = candidate persistent agent VM (execution plane only).
- GrokBot HQ = lightweight Next.js project to operate via worktrees and PRs.
- No Grok-native support in Matrix: adapter would be custom.

## Review checklist
- [ ] Vercel binding verified for the org fork
- [ ] `main` protected on the fork
- [ ] Matrix docs claims re-verified (see matrix-os.yaml)
- [ ] Pilot approved or rejected, reason recorded

## Where the detail lives
- docs/blueprints/matrix-os-pilot.md
- docs/blueprints/grokbothq-adoption.md
- config/blueprints/*.yaml

## Place in Drive
Save as the newest file in the Drive inbox folder used by agents, with the front matter unchanged.
