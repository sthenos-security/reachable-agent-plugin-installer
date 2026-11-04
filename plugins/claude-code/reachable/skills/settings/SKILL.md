---
name: settings
description: "Reachable: add AI or GitHub access, change what it does. Use when the user says reachable: settings, /reachable:settings, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/settings.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/settings.sh)
---

# reachable: settings

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/settings.sh"`

Relay the output. Keys are typed on the Settings tab, never in chat.
