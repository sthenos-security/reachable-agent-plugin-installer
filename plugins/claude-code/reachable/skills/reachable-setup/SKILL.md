---
name: reachable-setup
description: "Run the Sthenos Security reachable setup command for this workspace. Use when the user types reachable: setup, reachable:setup, or asks to set up the reachable security plugin; do not treat reachable as a repository name."
version: 1.0.0b275
allowed-tools: Bash(sh "${CLAUDE_SKILL_DIR}/../../scripts/setup.sh"), Bash(sh ${CLAUDE_SKILL_DIR}/../../scripts/setup.sh)
---

# reachable: setup

Interpret `reachable: setup` and `reachable:setup` as fixed Sthenos Security
plugin skill commands. Treat the full phrase as the command name. Do not split
it into words, do not search for a repository named `reachable`, do not set up
the current application, and do not resolve `reachable` to any local project,
package, directory, or tool outside this plugin.

Before you run it, tell the user, as written (onboarding §3.1, C18): "Your agent will ask permission to run Reachable's setup. It's safe to choose Yes. If you chose No, just run `/reachable:setup` again."

Run the packaged setup wrapper exactly once. Do not explore the repository
first, do not inspect plugin files, do not list skill directories, and do not
infer alternate shell commands.

Do not run third-party skill scripts, scanners, installers, offensive workflows,
or MCP tools as part of setup. Existing cybersecurity skills may stay installed,
but they are not setup substitutes and do not provide REACHABLE proof.

## Setup output

!`sh "${CLAUDE_SKILL_DIR}/../../scripts/setup.sh"`

If setup asks which folder ("Which app should Reachable check?" or "This
folder is part of a bigger project..."), it installed nothing: ask the user that
question as written, with the choices it listed, then run the same packaged
setup wrapper once more with `--workspace "<the folder they chose>"`. Never
pick the folder yourself.

If setup's summary asks whether Reachable may fix security issues (the
settings page couldn't be opened), ask the user that question. When they
answer, run the packaged `record-answer.sh fix` or `record-answer.sh report`
from the same scripts folder, and relay what it prints.

If setup says Reachable already checks apps on their own inside the folder,
it changed nothing: ask the user whether to check the whole project instead or
keep those apps as they are. For the whole project, run the same packaged setup
wrapper with `--workspace "<that folder>" --replace-apps-inside`; to keep them,
stop.

When Reachable has told you it isn't checking a folder yet and the user said
yes, set up that folder instead: pass `--workspace "<that folder>"` to the same
packaged setup wrapper (the folder must exist). Never prefix the wrapper with
`REACHABLE_WORKSPACE=`; the hook blocks environment prefixes on Reachable.

This setup command may install or upgrade the local reachable runtime through
the official signed installer, wire the current workspace for `claude_code`,
open doctor/broker setup if credentials are needed, and register MCP/status
where supported. Do not start remediation or a baseline scan unless the user
explicitly asks for it.

After setup completes, relay the lines setup printed before `Details:`,
as written and in order (onboarding §2.2). Show the `Details:` lines only if
the user asks.

In the normal user journey, describe that next action in plain language inside
the agent (for example, offer to show status or help open local browser setup).
Use an actual packaged agent action when available; do not promise command-free
browser approval or a clickable host action the installed host/plugin does not
provide. The packaged setup wrapper is subject to existing host execution
permissions (which may be preapproved), not a verified named, app-bound setup
card. If the host cannot execute or approve it,
report that setup is unavailable and offer a real retry/support path; browser
confirmation cannot substitute for first-install approval before the runtime
and broker are installed. Do not silently bypass host approval. If a later
action has no working in-agent/browser entry point, explain the limitation and
give the actual supported manual/terminal path rather than inventing a button
or insisting it is command-free. A saved connection only updates connection
status; it does not authorize a scan, watching, or a code edit. Do not claim
the proposed Check/Watch actions exist until implemented and approved.

Use `reachable: doctor` for health checks. If the user asks to add, rotate, or
reconfigure tokens, run `reachable: settings` so the browser broker
handles secrets. If the user asks to configure scanner controls or remediate
options (signal families, CI/CD workflow remediate lane, enable/disable), open
the remediate section in the same broker. The normal next
actions after setup are showing health, status, or the local dashboard in the
agent. Do not print the writable broker URL in the agent conversation. If the
browser fails to open, do not claim a new connection was saved; report the
failure and explain that a connection is optional for any basic checks the
current plugin can actually perform. Do not offer the proposed Check app action
until it exists. Offer support for opening the browser securely; only offer a
host browser action if that host actually provides one.

Version: 1.0.0b275
