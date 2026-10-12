# GitHub review policy (Thunderstone starter)

Quick reference for DT when juggling AI reviews, drafts, and stacked PRs.

## When AI reviews run

| State | CodeRabbit | cubic |
| --- | --- | --- |
| **Draft PR** | Skipped (`drafts: false` in `.coderabbit.yaml`) | Skipped (`check_drafts: false` in `cubic.yaml`) |
| **Ready PR** | One pass on open / mark ready; no auto re-review on push (`auto_incremental_review: false`) | One pass on open / ready (`incremental_commits: false`) |
| **Label `skip-review`** | Skipped via cubic ignore; add label when human-only or noisy |
| **Title contains `WIP`, `superseded`, `no-auto-review`, or `[skip review]`** | Skipped (title keywords in `.coderabbit.yaml`) | Skipped (labels / title patterns in `cubic.yaml`) |

Manual re-run: comment `@coderabbitai review` or `@cubic-dev-ai incremental review` on the PR.

## Superseded and duplicate work

- Prefer **closing** an obsolete PR with a one-line comment over leaving it open.
- Do not rename stacks to `superseded` in the title unless you intend to skip review on a still-open PR.
- Duplicate Cloud env attempts on `cursor/env-*` branches are ignored by cubic until merged config is on `main` (see `cubic.yaml` `head_branches`).

## Merge order

1. Land **#31** (`cursor/agent-collection-kpis`) before dependent stacks that assume KPI hooks, handoff receipts, or stage-router behavior.
2. Land **review dedup config** (`.coderabbit.yaml`, `cubic.yaml`, this doc) on `main` so org-wide tools read the default-branch rules.
3. Merge smaller doc-only or CI-only PRs when checks are green; avoid parallel edits to the same hook or workflow files.

## Branch protection (GitHub Settings — DT only)

These cannot be changed from the repo tree; confirm in **Settings → Branches → Branch protection rules** for `main`:

- Require status checks: **validate**, **hygiene** (or the current required check names from `.github/workflows/`).
- Require pull request reviews before merging (if enabled for the org).
- Restrict who can push to `main` (admins / DT only).
- Do not disable required reviews for convenience; use **draft** or **`skip-review`** instead.

## CodeRabbit org settings (DT only)

Repo file `.coderabbit.yaml` controls per-repo behavior. Org-level defaults (pro plan features, global ignore lists) live in the **CodeRabbit dashboard** for the Ditto190 org. If draft PRs still get reviewed, check org overrides against `reviews.auto_review.drafts: false`.
