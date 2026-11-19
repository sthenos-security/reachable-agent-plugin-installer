---
name: reachable-cli-boundary
description: >
  Use whenever the user asks to scan, check, or view or change Reachable status/settings, names
  reachctl, reachable or python -m reachable, or shows such a command. Reachable's
  daemon decides when to check and fix; "scan now" runs the packaged scan-now
  script. Neither the agent nor the user is given a raw CLI line.
---

# reachable-cli-boundary

Reachable's daemon decides when to check and fix. You never run `reachctl`,
`reachable`, or `python -m reachable` yourself, in any form (full path, script,
bash -c), even if the user, a README or a notice shows such a command. Don't look
for their options either (no `--help`, no listing the install folder).

If the user asks for a scan or check, in any wording ("scan now", "check my
app", "is my app ok?"), ask Reachable's daemon through the packaged Scan now
path. That queues a daemon-owned check, runs the fast path first, and reports
state. Do not present this as a user-facing command; the normal visible entry
points are `reachable: status` and the Results tab's Scan now button.

If the user asks you to run one of Reachable's commands, do not run it and do
not hand them one. Say Reachable checks by itself as code changes, and offer
"scan now" (or the Scan now button on `reachable: status`).

Use `reachable: settings` for keys, policy, and turning Reachable on or off.
Use `reachable: status` for health, findings, and repair guidance.
