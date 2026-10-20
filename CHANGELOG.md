# Changelog
All notable changes to this project are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Entries are generated per merged PR by `scripts/changelog-entry.sh` and collected in the draft
"Unreleased" GitHub release by the `Release notes` workflow (no bot commits to `main`). At release
time, copy the draft notes into this file in a normal PR authored by the `Ditto190` alias.

## [Unreleased]

### Added
- Agent-selection toolkit core: scripts/catalog.mjs, scripts/select.sh, acceptance tests (#15)
- Stage-aware sessionStart advisory hook (`.cursor/hooks/stage-router.sh`) routing Monitor > Triage > Build, with fixture tests and `docs/stage-router.md` (#8)
- CI, security and hygiene workflows with pinned actions and required checks (#1)
- Browser stack bootstrap: CloakBrowser CDP sidecar, agent-browser, Scrapling and Firecrawl wiring (#3)
- Single-pass AI review pipeline (CodeRabbit + cubic), PR labeler, label set and release-notes automation
