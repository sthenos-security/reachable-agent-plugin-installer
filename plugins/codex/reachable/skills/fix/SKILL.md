---
name: fix
description: "Reachable: fix the problems it found. Use when the user says reachable: fix, /reachable:fix, or asks for this in their own words."
---

# reachable: fix

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/fix.sh`.


Relay the output to the user as written.
