---
description: Developer experience standards, sub-5-minute onboarding, and automation
globs: ["**/*"]
always_on: true
---

# Developer Experience (DX) Guidelines

Our core objective is to minimize friction, automate repetitive developer toil, and maintain instantaneous feedback loops across both Windows and Linux.

## 1. The Sub-5-Minute Rule
- A developer or agent arriving in this repository must be able to verify their entire environment in under 5 minutes using automated doctor scripts:
  - Windows: `py workspace/scripts/clan_tool.py doctor`
  - Linux: `bash scripts/doctor.sh`
- Never require manual configuration of files that can be automatically derived or defaulted.

## 2. Friction Detection & Elimination
- Any manual sequence performed more than twice a day must be encapsulated in a one-line script or CLI command.
- If a command fails due to missing dependencies or permissions, output an actionable fix rather than a raw stack trace.

## 3. Fast Verification Loops
- Single-command validation: `npm test` runs hygiene checks, ShellCheck, and core tests.
- Local commits and handoffs must produce explicit receipts rather than unverified diffs.
