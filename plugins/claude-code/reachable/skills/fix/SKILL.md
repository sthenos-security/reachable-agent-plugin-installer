---
name: fix
description: "Reachable: fix the problems it found. Use when the user says reachable: fix, /reachable:fix, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/fix.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/fix.sh)
---

# reachable: fix

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/fix.sh"`

Relay the output to the user as written.
