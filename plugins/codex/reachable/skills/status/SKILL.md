---
name: status
description: "Reachable: what Reachable is doing, what it found and fixed. Use when the user says reachable: status, /reachable:status, or asks for this in their own words."
---

# reachable: status

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/status.sh`.


Start your reply with the `answer` lines of the output, exactly and in order. Add details only when asked.
