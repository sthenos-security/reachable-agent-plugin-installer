---
name: help
description: "Reachable: every Reachable command. Use when the user says reachable: help, /reachable:help, or asks for this in their own words."
---

# reachable: help

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/help.sh`.
Allowed extra arguments: `more`.

Relay the output as written.
