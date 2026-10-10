# Changelog
All notable changes to this project are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Entries are generated per merged PR by `scripts/changelog-entry.sh` and collected in the draft
"Unreleased" GitHub release by the `Release notes` workflow (no bot commits to `main`). At release
time, copy the draft notes into this file in a normal PR authored by the `Ditto190` alias.

## [Unreleased]

### Added
- CI, security and hygiene workflows with pinned actions and required checks (#1)
- Browser stack bootstrap: CloakBrowser CDP sidecar, agent-browser, Scrapling and Firecrawl wiring (#3)
- Single-pass AI review pipeline (CodeRabbit + cubic), PR labeler, label set and release-notes automation
- Operations roster and groups consolidation: per-group bot profile patches, a short standard profile block and a one-line standing law (full auto-permission on the VM; third-party send/post/purchase and commit/push/delete still need DT approval)
  - Event-triggered `health.sh` and `startup.sh` wired as a non-blocking `sessionStart` hook (`failClosed: false`, 5 s timeout); no cron, timers or routines
  - `scripts/run-task.sh` launches the agent with `--force` and `LEAN_CTX_DISABLED=1` (agent process only), with a static check in `scripts/validate.sh` (#7, pending merge)
  - Browser stack runs without docker: CloakBrowser CDP on 127.0.0.1:9222, plus agent-browser and Scrapling; Firecrawl still needs a key
