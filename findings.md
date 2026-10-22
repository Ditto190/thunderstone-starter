# Findings & Decisions

## Requirements
- Multi-environment harmony between Windows (Host/Cursor Desktop/Antigravity) and Linux (Grok VM / WSL2 Ubuntu / Codespaces).
- Full integration of Antigravity Customizations (`.agents/` discovery, rules, hooks, MCP configs) alongside Cursor's `.cursor/`.
- Context7 auto-research configuration without duplicating marketplace plugins.
- Backend development guidelines with explicit BFRI risk scoring, layered design, and deterministic error handling.
- Bash/Linux operational patterns for the remote VM combined with PowerShell best practices on Windows.
- DX optimization: sub-5-minute onboarding, intelligent defaults, and fast verification loops.
- Personal tool builder: pragmatic CLI tooling for quick clan health checks and handoff queries.

## Research Findings

### Environment Comparison Matrix
| Dimension | Windows Host (Local) | Grok VM / WSL2 (Remote/Linux) |
|---|---|---|
| **Primary Shell** | PowerShell 7 / Windows Terminal | Bash (with `set -euo pipefail`) |
| **Node.js** | Node v24.16.0 | Node v22.23.2+ (managed by bootstrap.sh) |
| **Python** | Python 3.14.6 via `py` launcher | Python 3.10+ via `python3` |
| **Agent Runtimes** | Antigravity 2.0 / Cursor Desktop / AG2 | Cursor Cloud Worker (`grok-shared`), tmux session |
| **Path Conventions** | Backslashes handled; forward slashes preferred | POSIX forward slashes, case-sensitive |
| **Process Locks** | In-process / OS file handles | Linux kernel `flock` |

### Antigravity Loading Rules
1. Workspace Project: `.agents/` directory at root (highest priority).
2. Project Rules: `GEMINI.md`, `AGENTS.md`, and `.agents/rules/*.md`.
3. Progressive disclosure: Skills and model-decision rules are loaded on demand to conserve context window.
4. Deduplication: Rule files are deduplicated by resolved canonical file path.

### Backend Risk & Feasibility Index (BFRI)
- Formula: `BFRI = (Architectural Fit + Testability) - (Complexity + Data Risk + Operational Risk)`
- Range: `-10` to `+10`. Any change with BFRI `< 3` requires isolation, refactoring, or pre-implementation approval.

## Technical Decisions
| Decision | Rationale |
|---|---|
| Maintain `.agents/` alongside `.cursor/` | Enables full native Antigravity support while keeping Cursor Cloud Agents and Cursor hooks 100% functional. |
| Use Python for cross-platform tooling (`clan_tool.py`) | Python is present on both hosts (`py` on Windows, `python3` on Linux VM), avoiding shell syntax incompatibilities. |
| Cross-platform MCP runner via `node scripts/env-run.mjs` | Standardizes environment variable injection (`CONTEXT7_API_KEY`) across both Windows and Linux without shell-sourcing risks. |
| File-based working memory (`task_plan.md`, `findings.md`, `progress.md`) | Follows Manus-style persistent working memory on disk to survive agent restarts and long tool chains. |
