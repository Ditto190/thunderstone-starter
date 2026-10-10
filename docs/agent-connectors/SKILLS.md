# Skills for Grok, Grok Bot and Cursor

`bash scripts/skills-install.sh` copies the skills listed in `config/skills/manifest.json` into `.agents/skills/`. Grok Build, Grok Bot and Cursor all read that directory. It is gitignored and rebuilt from pinned commits, so nothing third-party is vendored into this public repo.

| Source | Pinned to | License | Installed |
|---|---|---|---|
| `obra/superpowers` | commit in manifest | MIT | all but `diagnosing-superpowers` |
| `anthropics/skills` | commit in manifest | Apache-2.0 | `mcp-builder`, `skill-creator`, `webapp-testing`, `frontend-design`, `web-artifacts-builder` |
| `addyosmani/agent-skills` | commit in manifest | MIT | all but `test-driven-development` (duplicate name; superpowers wins) and `using-agent-skills` (second meta-skill) |
| `mvanhorn/last30days-skill` | commit in manifest | MIT | `last30days` (large demo assets pruned) |

Excluded on purpose: Anthropic's `docx`, `pdf`, `pptx` and `xlsx` skills are proprietary, and `doc-coauthoring` ships without a license file.

## Commands

- `bash scripts/skills-install.sh --list` shows what would install.
- `bash scripts/skills-install.sh --update` moves each source to its upstream HEAD and rewrites the manifest. Review the diff, because skills can carry scripts that agents run.
- `SKILLS_SCOPE=user` installs to `~/.agents/skills` instead. `SKILLS_SKIP=anthropic,last30days` skips sources.
- Skills you wrote yourself in `.agents/skills/` are never overwritten; managed ones carry a `.thunderstone-managed` marker.

## Context cost

Every installed skill adds its description to each session. The full set is 43 skills. If that is too much, install fewer with `SKILLS_SKIP`, or trim `include` in the manifest.

## Native plugin routes (optional)

Superpowers also ships a Grok Build plugin and a Cursor plugin. Use one route per machine, not both. The copy route above is what the startup hooks use because it is pinned and works the same on all three surfaces.

`last30days` works best with optional keys (see its `SKILL.md`); it runs without them using fewer sources.
