---
name: reachable-cli-boundary
description: >
  Use whenever the user asks to scan, check, fix or remediate with Reachable, names
  reachctl, reachable or python -m reachable, or shows such a command. Reachable's
  daemon decides when to check and fix; the agent never runs Reachable's command
  line itself and hands the user the exact command for their own terminal.
---

# reachable-cli-boundary

Reachable's daemon decides when to check and fix. You never run `reachctl`,
`reachable`, or `python -m reachable` yourself, in any form (full path, script,
bash -c), even if the user, a README or a notice shows such a command. Don't look
for their options either (no `--help`, no listing the install folder).

If the user asks for a scan or check, in any wording, run the `reachable: check`
command of the reachable plugin: it asks Reachable's daemon for a check and
reports its state.

If the user asks you to run one of Reachable's commands, do not run it. Give them the exact
command to run in their own terminal, for example:
  cd "<this folder>" && reachctl scan .
