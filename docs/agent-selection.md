# Agent selection

Pick one local skill for a task. `scripts/select.sh` ranks shared skills from a generated catalog. Exit 0 prints TSV (`score`, `kind`, `id`, `cost`, `path`, `hitwords`). Exit 1 prints `NO_MATCH` (fall back to house-rules routing). Exit 2 is bad usage or a missing skills root.

## select.sh

```sh
bash scripts/select.sh "<task>" [--kind skill|agent|plugin] [--top N] [--json] [--root DIR] [--external]
```

`--kind` keeps one kind (`agent` and `plugin` are accepted; this core indexes skills). `--top` is 1–20 (default 3). `--json` prints a JSON array; an empty array still exits 1. `--root` overrides the skills root for that run. When `CATALOG` is unset, `--root` always builds a temp catalog from that root.

## catalog.mjs

```sh
node scripts/catalog.mjs gen [--root DIR] [--out DIR] [--verbose]
node scripts/catalog.mjs select CATALOG "<task>" [--kind k] [--top N] [--json] [--root DIR]
```

`gen` indexes `SKILL.md` under one root. Without `--out` it prints `catalog.json` on stdout. With `--out` it writes `catalog.json` and `llms.txt` in that directory. `select` scores the catalog, then re-reads each hit on disk.

## Environment

| Variable | Role |
|---|---|
| `THUNDERSTONE_SKILLS_ROOT` | Canonical skills root when `--root` is omitted. Default is `../skills` beside the script. A missing root is an error. |
| `CATALOG` | `catalog.json` for `select.sh`. Default is `../catalog/catalog.json`. An explicit value is always used. If unset and `--root` is set, a temp catalog is generated from that root. If unset, `--root` is omitted, and the default file is absent, a temp catalog is generated. |
| `EXTERNAL_LLMS_URL` | Public `llms.txt` for `--external`. Default is the awesome-copilot index. |

`catalog/` is generated and gitignored. Paths inside it are machine-local. Do not commit it.

## Frontmatter

Each indexed file is `<id>/SKILL.md`. `tags` is a kebab-case list, either `tags: a, b` or `tags: [a, b]`. A query token that matches a tag gets a +1.5 score boost on top of the usual keyword score. `scope` is `shared` or `private`. Omitted scope means `shared`. `private` is never indexed and never returned.

```markdown
---
name: example-skill
description: Use when packing crates for storage.
tags: [crate-pack, storage]
scope: shared
---
```

## Wire-in

Add this line to agent prompts (already in `AGENTS.md`):

`Unsure which skill? Run bash scripts/select.sh "<task>" and load only the top hit's SKILL.md. NO_MATCH (exit 1) -> route per house-rules; never guess.`

`scripts/ts-select.sh` is the `ts-*` wrapper. It resolves `select.sh` beside itself, forwards every argument, and returns the same stdout and exit code. `--help` prints usage and exits 0. It does not use the network unless `--external` is passed through.

## Private deny-by-default

Only the canonical root is read. Symlinks are not followed. Frontmatter `scope: private` is never written and never returned, including an exact id match. Unknown scope, duplicate keys, unreadable frontmatter, or a missing description skips the item. `select` drops a hit whose file is private, missing, or outside the root.

## --external

Optional and read-only. The task text is not sent. The script downloads the public `llms.txt` and greps it locally for up to three lines. Nothing is installed.

## Tests

```sh
npm test
THUNDERSTONE_REAL_SKILLS=<skills-root> bash scripts/tests/select-test.sh
```

`THUNDERSTONE_REAL_SKILLS` points gate 11 at a real skills tree. `SELECT_TEST_VERBOSE=1` prints per-test names. `npm test` also runs ShellCheck and `scripts/check-hygiene.sh`.

Mirror drift and catalog pickup are checked on demand by `scripts/skills-sync-check.sh`. See [skills-sync.md](skills-sync.md).
