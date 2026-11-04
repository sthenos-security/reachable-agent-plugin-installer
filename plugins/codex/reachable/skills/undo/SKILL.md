---
name: undo
description: "Reachable: undo the last Reachable fix. Use when the user says reachable: undo, /reachable:undo, or asks for this in their own words."
---

# reachable: undo

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/undo.sh`.
Allowed extra arguments: `--confirmed`.

Relay the output. If it asks 'Undo anyway?', relay the question; only after the user says yes, run the same wrapper again with `--confirmed`.
