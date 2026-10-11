---
description: Use when editing stage rules, roster ownership, or doc-source checks for Thunderstone.
---

# Domain model

Stage policy is the ordered `rules` array in `config/domain/stages.json`. Predicates are `signal`, `any`, and `all`. First match wins.

Roster ownership is `config/domain/roster.json`. Doc scans read `config/domain/doc-sources.json` and require every `scripts/*.sh` or `scripts/*.mjs` mention to exist.

Change those records. Then run `node --test services/domain-analysis/analyze.test.mjs`.
