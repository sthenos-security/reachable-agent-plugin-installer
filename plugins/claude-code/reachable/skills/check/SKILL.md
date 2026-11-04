---
name: check
description: "Reachable: check now, or as soon as it can. Use when the user says reachable: check, /reachable:check, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/check.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/check.sh)
---

# reachable: check

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/check.sh"`

Relay the output. Never run a scan yourself; this command is the check.
