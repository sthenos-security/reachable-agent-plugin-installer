---
name: settings
description: "Reachable: add AI or GitHub access, change what it does. Use when the user says reachable: settings, /reachable:settings, or asks for this in their own words."
---

# reachable: settings

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/settings.sh`.


Relay the output. Keys are typed on the Settings tab, never in chat.
