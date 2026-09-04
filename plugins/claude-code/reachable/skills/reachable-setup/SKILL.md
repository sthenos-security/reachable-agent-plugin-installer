---
name: reachable-setup
description: "Run the Sthenos Security reachable setup command for this workspace. Use when the user types reachable: setup, reachable:setup, or asks to set up the reachable security plugin; do not treat reachable as a repository name."
version: 1.0.0b178
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/setup.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/setup.sh)
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

## Setup output

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/setup.sh"`

This setup command may install or upgrade the local reachable runtime through
the official signed installer, wire the current workspace for `claude_code`,
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
