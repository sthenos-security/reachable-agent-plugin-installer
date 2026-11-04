---
name: report-a-problem
description: "Reachable: something not working, or a question. Use when the user says reachable: report a problem, /reachable:report-a-problem, or asks for this in their own words."
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/report-problem.sh" *), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/report-problem.sh *)
---

# reachable: report a problem

Run `sh "${CLAUDE_SKILL_DIR}/../../scripts/report-problem.sh"` with the arguments below.

First ask 'What went wrong, in your own words?'. Run the wrapper with `--what "<their words>"`, relay what it includes, and only after the user says yes run it again with `--confirmed`; give them the reference it prints.
