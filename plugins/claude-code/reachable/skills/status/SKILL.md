---
name: status
description: "Reachable: what it found and fixed, and what it's doing now. Use when the user says reachable: status, /reachable:status, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/status.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/status.sh)
---

# reachable: status

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/status.sh"`

Start your reply with the `answer` lines of the output, exactly and in order. Add details only when asked.
