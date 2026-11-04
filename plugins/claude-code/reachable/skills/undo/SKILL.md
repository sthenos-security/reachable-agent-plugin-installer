---
name: undo
description: "Reachable: undo the last Reachable fix. Use when the user says reachable: undo, /reachable:undo, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/undo.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/undo.sh), Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/undo.sh" --confirmed), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/undo.sh --confirmed)
---

# reachable: undo

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/undo.sh"`

Relay the output. If it asks 'Undo anyway?', relay the question; only after the user says yes, run the same wrapper again with `--confirmed`.
