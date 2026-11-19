---
name: scan-now
description: "Reachable: scan this app now (the Scan now button). Use when the user says reachable: scan now, /reachable:scan-now, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/check.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/check.sh)
---

# reachable: scan now

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/check.sh"`

Relay the output. Never suggest a raw Reachable CLI line instead.
