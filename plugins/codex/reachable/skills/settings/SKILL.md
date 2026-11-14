---
name: settings
description: "Reachable: keys, and turning Reachable on or off. Use when the user says reachable: settings, /reachable:settings, or asks for this in their own words."
---

# reachable: settings

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/settings.sh`.


Relay the output. Keys are typed on the settings page, never in chat.
