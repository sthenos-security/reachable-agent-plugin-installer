---
name: scan-now
description: "Reachable: scan this app now (the Scan now button). Use when the user says reachable: scan now, /reachable:scan-now, or asks for this in their own words."
---

# reachable: scan now

Keep the current workspace as the working directory. Resolve the plugin package
root as the directory that contains both `scripts/` and `skills/`,
then run exactly this wrapper by absolute path: `$PLUGIN_ROOT/scripts/check.sh`.


Relay the output. Never suggest a raw Reachable CLI line instead.
