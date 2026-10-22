---
description: Personal tool building philosophy and CLI ergonomics
globs: ["scripts/**/*", "workspace/scripts/**/*"]
always_on: false
---

# Personal Tool Building Guidelines

Adopt the "scratch-your-own-itch" philosophy: the best tools emerge from real, recurring personal friction.

## 1. The 10-Minute Test
Before building a personal script or utility, confirm:
1. Can the problem be stated in one concise sentence?
2. Does this friction happen at least weekly?
3. Have you attempted solving it manually first?
4. Would you use this tool daily?

## 2. CLI Ergonomics
- Provide concise commands and short flags (`--help`, `-h`, `status`, `doctor`, `verify`).
- Clean stdout output: print only actionable progress and summary data; avoid noisy dumps.
- Return exit code `0` on success, non-zero on failure.
- Design scripts to evolve gracefully: start as a focused personal script, dogfood it, and promote it to shared workspace scripts.
