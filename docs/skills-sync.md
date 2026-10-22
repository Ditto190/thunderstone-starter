# Skills sync check

`scripts/skills-sync-check.sh` compares one canonical skills root with zero or more mirrors and checks that a generated catalog picks up every shared skill. It is read-only and event-driven. Run it when skills change. There is no cron.

Grok Bot catalog pickup means bots read `catalog.json` and `llms.txt` generated from the canonical root. After a skill edit, regenerate on demand:

```sh
node scripts/catalog.mjs gen --out catalog
```

`gen` writes `catalog.json` and `llms.txt` in `--out`. Skills with `scope: private` stay out of both files. See [agent-selection.md](agent-selection.md).

## Usage

```sh
bash scripts/skills-sync-check.sh \
  [--canonical DIR] \
  [--mirror DIR] \
  [--catalog DIR] \
  [--json] [--quiet] [--print-fix] [--strict]
```

`--mirror` may be repeated. `--print-fix` prints `rsync` commands and does not run them.

## Statuses

TSV columns are `status`, `id`, `mirror`, `detail`. `--json` prints the same rows as an array.

| status | meaning |
| --- | --- |
| `ok` | Mirror skill matches, or is a symlink to the canonical skill directory (`detail` `match` or `symlink`). |
| `drift` | File set or content differs. `detail` lists the relative paths. |
| `missing` | Canonical skill is absent from the mirror. |
| `extra` | Skill exists only in the mirror. Informational unless `--strict`. |
| `warn` | Canonical skill has no usable description, or `name` is not the folder id. Does not fail the run. |
| `pickup` | Fresh catalog missed a shared id, included a private id, or a `--catalog` tree disagrees. |
| `stale` | A canonical `SKILL.md` is newer than `--catalog` `catalog.json`. |

## Exit codes

| code | meaning |
| --- | --- |
| 0 | No drift and catalog pickup matches. Extra mirror skills are allowed. |
| 1 | Drift, a missing skill, catalog pickup failure, a stale catalog, or an extra skill with `--strict`. |
| 2 | Bad arguments or the canonical root is missing. |

`--quiet` prints nothing when the exit code is 0.

## Environment

| variable | role |
| --- | --- |
| `THUNDERSTONE_SKILLS_ROOT` | Default `--canonical` when the flag is omitted. |
| `SKILLS_MIRRORS` | Colon-separated default mirrors when `--mirror` is omitted. |

If neither `--mirror` nor `SKILLS_MIRRORS` is set, the checker only validates the canonical tree and catalog pickup.
