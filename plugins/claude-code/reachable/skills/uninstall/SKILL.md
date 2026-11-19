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
   If the runtime is missing or broken, the wrapper says so and removes
   REACHABLE without it: there is nothing to export then, and its list may
   end with items marked "left, needs the runtime". Show those to the user
   as they are; do not run setup and do not delete files by hand.
2. Show the preview to the user. Ask whether to export scan history and
   settings (credentials are excluded), unless the preview said there is
   nothing to export, and ask explicitly whether to remove
   REACHABLE from this computer, including credentials and scan history.
   Do not assume either answer. If the user declines, stop.
3. After an explicit yes and export choice, run `sh "${CLAUDE_SKILL_DIR}/../../scripts/uninstall.sh" --yes --no-export`
   or `sh "${CLAUDE_SKILL_DIR}/../../scripts/uninstall.sh" --yes --export <user-chosen-path>`. Pass an export path as one
   quoted argument. The host may also ask for permission to run the command.
4. Relay the result. If a step fails, say which step failed and do not claim
   removal finished. The uninstall stops REACHABLE's MCP servers, including
   this session's; tell the user to restart the agent so it stops listing the
   REACHABLE tools.
