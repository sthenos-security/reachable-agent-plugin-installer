---
name: help
description: "Reachable: every Reachable command. Use when the user says reachable: help, /reachable:help, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/help.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/help.sh), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/help.sh" more), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/help.sh more)
---

# reachable: help

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/help.sh"`

Relay the output as written.
