# Task Plan: Dual-Environment Antigravity & Linux VM Customization Stack

## Goal
Establish a unified, high-performance developer workflow and customization architecture across Windows host and Grok/Linux VM, incorporating Antigravity customizations (.agents), Context7 auto-research, backend engineering standards, bash/powershell parity, DX optimization, and personal CLI tooling.

## Current Phase
Phase 2: Rules & Customization Scaffolding

## Phases

### Phase 1: Requirements & Discovery
- [x] Scan workspace and map differences between Windows host (PowerShell, Node 24, Python 3.14 launcher) and Linux VM (Bash, Node 22, tmux, flock)
- [x] Analyze Antigravity customization loading hierarchy (.agents discovery, progressive disclosure, deduplication)
- [x] Review Context7, Backend Dev Guidelines (BFRI), Bash Linux, DX Optimizer, and Personal Tool Builder standards
- [x] Document discoveries and architectural decisions in findings.md
- **Status:** complete

### Phase 2: Rules & Customization Scaffolding
- [x] Initialize Manus-style persistent memory (task_plan.md, findings.md, progress.md)
- [ ] Create `.agents/rules/` with environment-tailored guidelines:
  - `windows-powershell.md`: PowerShell syntax, py launcher, path normalization
  - `linux-vm-bash.md`: Bash strict mode, tmux, flock, process management
  - `backend-standards.md`: Layered architecture, BFRI risk index, validation, error boundaries
  - `dx-standards.md`: Friction-free workflows, <5min onboarding, automated checks
  - `personal-tools.md`: Scratch-your-own-itch, 10-minute test, CLI ergonomics
- [ ] Create GEMINI.md project root anchor for Antigravity discovery
- **Status:** in_progress

### Phase 3: MCP & Context7 Integration
- [ ] Configure `.cursor/mcp.json` and `.agents/mcp_config.json` for Context7 auto-research and Caveman Cloud
- [ ] Ensure cross-platform execution via `env-run.mjs`
- **Status:** pending

### Phase 4: Personal Clan CLI Tooling (DX & Automation)
- [ ] Implement `workspace/scripts/clan_tool.py` as a cross-platform helper for environment diagnostics, handoffs, and receipts
- [ ] Verify execution on both Windows (`py`) and Linux VM syntax
- **Status:** pending

### Phase 5: Verification & Walkthrough
- [ ] Validate syntax and execution of all created rules, scripts, and configurations
- [ ] Run test suite and check promotion gates
- [ ] Generate walkthrough artifact
- **Status:** pending
