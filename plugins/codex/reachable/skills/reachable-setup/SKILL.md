---
name: reachable-setup
description: "Run the Sthenos Security reachable setup command for this workspace. Use when the user types reachable: setup, reachable:setup, or asks to set up the reachable security plugin; do not treat reachable as a repository name."
version: 1.0.0b178

---

# reachable: setup

Interpret `reachable: setup` and `reachable:setup` as fixed Sthenos Security
plugin skill commands. Treat the full phrase as the command name. Do not split
it into words, do not search for a repository named `reachable`, do not set up
the current application, and do not resolve `reachable` to any local project,
package, directory, or tool outside this plugin.

Run the packaged setup wrapper exactly once. Do not explore the repository
first, do not inspect plugin files, do not list skill directories, and do not
infer alternate shell commands.

Do not run third-party skill scripts, scanners, installers, offensive workflows,
or MCP tools as part of setup. Existing cybersecurity skills may stay installed,
but they are not setup substitutes and do not provide REACHABLE proof.

## Setup command

Keep the current workspace as the working directory. Do not `cd` into the
plugin package.

Resolve the plugin package root as the directory that contains both
`scripts/` and `skills/`, then run exactly this wrapper once by
absolute path:

`$PLUGIN_ROOT/scripts/setup.sh`

`$PLUGIN_ROOT/bin/reachable-setup` is an optional alias that execs the
same script. Do not invent other paths, do not search the repository or PATH
for a substitute, and do not run `bin/reachable-mcp` for setup. If the
wrapper is missing or not executable, stop and tell the user to reinstall the
Sthenos Security reachable plugin or contact <https://sthenosec.com>.

This setup command may install or upgrade the local reachable runtime through
the official signed installer, wire the current workspace for `codex`,
open doctor/broker setup if credentials are needed, and register MCP/status
where supported. Do not start remediation or a baseline scan unless the user
explicitly asks for it.

After setup completes, report only the high-level result:

- Installed reachable version
- Workspace
- Scanner readiness
- Agent wiring
- Monitoring state
- Baseline scan state
- Remediation state
- One next action

Use `reachable: doctor` for health checks. If the user asks to add, rotate, or
reconfigure tokens, run `reachable: doctor --configure` so the browser broker
handles secrets. If the user asks to configure scanner or
remediation, open the remediation section in the same broker. The normal next
prompts after setup are `reachable: doctor`, `reachable: status`, and
`reachable: remediation status`.

Version: 1.0.0b178
