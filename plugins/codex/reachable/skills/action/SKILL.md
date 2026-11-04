---
name: action
description: "Reachable: allow-fixes, report, stop or start. Use when the user says reachable: action, /reachable:action, or asks for this in their own words."
---

# reachable: action

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/action.sh`.
Allowed extra arguments: `ask-first`, `report`, `stop`, `start`, `allow-fixes`.

With no choice it shows the setting. Pass exactly one choice the user asked for. Relay the output.
