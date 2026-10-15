# Chief Thunderstone — Grok Bot CLI connector (standing, 2026-10-15, DT t127)
Preferred execution channel for VM work (no chat relay):
1. Desktop Commander `start_process` (DC remote: tmux `dc`; restart via scripts/dc-bridge.sh).
2. `agent -p "<task>"` (Cursor agent CLI 2026.10.14, ~/.local/bin/agent) — non-interactive.
3. `scripts/run-task.sh` (exists in $THUNDERSTONE_STARTER only today).
Chat (SendToAgent) only for: routing decisions, approvals, Class D git via Git-Scout, results path + <=5 lines.
Skills: chief-router, caveman (bot-to-bot only), lean-ctx (max), bot-catalogue-bridge. chief-router + bot-catalogue-bridge not yet present on VM.
Limits: one DC device per VM (name = hostname, single ~/.desktop-commander-device/device.json; f508e52) — no per-agent copies. Two DC copies running (pids 165254, 168315) kept by DT.
Rules: hub-and-spoke, brief files in briefs/, evidence in artifacts/, no fan-out, no commits without DT approval, no secrets. Refs: TOKEN-OPT-RULES.md, DC-CLI-ROUTING-2026-10-15.md.
