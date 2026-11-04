---
name: action
description: "Reachable: allow-fixes, report, stop or start. Use when the user says reachable: action, /reachable:action, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/action.sh), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh" ask-first), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/action.sh ask-first), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh" report), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/action.sh report), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh" stop), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/action.sh stop), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh" start), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/action.sh start), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh" allow-fixes), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/action.sh allow-fixes)
---

# reachable: action

Run `sh "${CLAUDE_SKILL_DIR}/../../scripts/action.sh"` with the arguments below.

With no choice it shows the setting. Pass exactly one choice the user asked for. Relay the output.
