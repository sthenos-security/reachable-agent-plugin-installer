---
name: report-a-problem
description: "Reachable: something not working, or a question. Use when the user says reachable: report a problem, /reachable:report-a-problem, or asks for this in their own words."
---

# reachable: report a problem

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/report-problem.sh`.


First ask 'What went wrong, in your own words?'. Run the wrapper with `--what "<their words>"`, relay what it includes, and only after the user says yes run it again with `--confirmed`; give them the reference it prints.
