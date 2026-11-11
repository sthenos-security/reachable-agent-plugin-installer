---
name: uninstall
description: "Reachable: remove Reachable from this computer. Use when the user says reachable: uninstall, /reachable:uninstall, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/uninstall.sh" --preview)
---

# reachable: uninstall

This is an in-agent command for full removal from this computer. Keep the
current app folder as the working directory. Use only this packaged wrapper;
do not run raw `reachctl`, curl or manual file deletion.

1. Preview without removal: !`sh "${CLAUDE_SKILL_DIR}/../../scripts/uninstall.sh" --preview`
   If the wrapper reports that the runtime is missing or unhealthy, explain
   that full removal needs a working runtime. Ask before running the packaged
   `reachable: setup` skill to repair it, then retry this preview. If repair
   fails, report the incomplete uninstall; do not delete files by hand.
2. Show the preview to the user. Ask whether to export scan history and
   settings (credentials are excluded), and ask explicitly whether to remove
   REACHABLE from this computer, including credentials and scan history.
   Do not assume either answer. If the user declines, stop.
3. After an explicit yes and export choice, run `sh "${CLAUDE_SKILL_DIR}/../../scripts/uninstall.sh" --yes --no-export`
   or `sh "${CLAUDE_SKILL_DIR}/../../scripts/uninstall.sh" --yes --export <user-chosen-path>`. Pass an export path as one
   quoted argument. The host may also ask for permission to run the command.
4. Relay the result. If a step fails, say which step failed and do not claim
   removal finished. A running agent session may retain its MCP child until
   that agent restarts; tell the user to restart it.
