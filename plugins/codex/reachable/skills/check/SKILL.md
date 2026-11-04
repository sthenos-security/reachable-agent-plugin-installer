---
name: check
description: "Reachable: check now, or as soon as it can. Use when the user says reachable: check, /reachable:check, or asks for this in their own words."
---

# reachable: check

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/check.sh`.


Relay the output. Never run a scan yourself; this command is the check.
