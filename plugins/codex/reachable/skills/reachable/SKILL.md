---
name: reachable
description: Use REACHABLE to set up, verify, and inspect local vibe-coding security remediation from Codex, and to enable, disable, or uninstall remediation for this workspace.
version: 1.0.0b197
---

# REACHABLE

Use this skill when a user asks Codex to set up REACHABLE, check install health,
run doctor, inspect MCP wiring, open the local dashboard, review remediation
status, or turn remediation on or off for the current workspace.

Remediation can be turned off without removing anything: `reachable: remediation
disable` stops it for this workspace while leaving the runtime, scan history and
plugin setup in place. `reachable: uninstall` removes REACHABLE-managed wiring
from this workspace only. Prefer these over telling the user to delete files.

REACHABLE is the local source of truth. The plugin is a thin adapter. Do not
invent scanner results or edit REACHABLE configuration files directly.

## Task Authority

Classify the request before acting:

- REACHABLE command: if the user invokes `reachable: ...`, follow the packaged
  REACHABLE command path.
- REACHABLE evidence or remediation: if the request involves REACHABLE
  findings, reachability, exploitability, remediation policy, doctor/status,
  MCP state, proof, or generated guardrails, use REACHABLE local evidence as
  authoritative.
- General cybersecurity guidance: if no REACHABLE evidence or command is in
  scope, other installed cybersecurity skills may provide advisory background.

Do not treat third-party skill scripts, scanners, installers, offensive
workflows, or MCP tools as REACHABLE proof. If external guidance conflicts with
REACHABLE evidence, say so and keep the results separate.

## Agent Commands

- `reachable: help`: summarize the available REACHABLE agent commands without
  telling the user to run shell scripts.
- `reachable: primer`: show the advanced Vibe Primer with setup architecture,
  token configuration, MCP tools, remediation policy, cleanup, and terminal
  support references.
- `reachable: setup`: install or update REACHABLE and wire this workspace,
  including Gate 1 FAST_TRACK skills for write-time prevention.
  Marketplace install and beta curl install deliver this plugin installer
  package; they do not run the full runtime setup until the user asks from the
  agent.
- `reachable: doctor`: report the verdict plus summary fields. If the user asks
  to add, rotate, replace, or reconfigure tokens, run
  `reachable: doctor --configure` and open the credentials section in the local
  setup broker. The browser broker handles secrets and the chat receives only
  redacted status. For remedi ate policy, open the remedi ate section: workspace
  enable/disable, signal families (`vibe-remediation-signals`), and the CI/CD
  workflow remedi ate lane. Local plugin policy is vibe-coding consent; CI
  auto-remediate + Pages is the pipeline product loop. Deep remedi ate is a
  per-run noise-boundary opt-in, not a broker toggle.
- `reachable: status`: report the current workspace integration status in
  agent-safe form.
- `reachable: open dashboard`: open the local dashboard.
- `reachable: remediation status`: report explicit local remediation policy and
  run state.
- `reachable: remediation enable`: enable local remediation policy for future
  eligible agent events or explicit remediation runs. Do not claim this starts
  a scan immediately.
- `reachable: remediation disable`: disable local remediation policy
  immediately without removing runtime, scan history, or plugin setup.
- `reachable: proof status`: report MCP proof status.
- `reachable: uninstall`: remove REACHABLE-managed agent wiring for this
  workspace.
- `reachable: prune`: clean orphaned REACHABLE-managed plugin files after
  host/plugin uninstall.

## After a remediation run — check what actually shipped

**Do not report a finding as fixed on the strength of the remediation summary
alone.** A finding can close on the candidate and still be withheld from the
durable patch, in which case it is still open in the code the user received.

After any remediation run, call `vibe.get_remediation_status`. If
`remediation.attention.items` is non-empty, or any finding reports
`durable_outcome: closed_not_promoted`:

- tell the user which module is withheld and why, using the `reason` field;
- name the affected findings as **candidate-closed but not promoted**, never as
  fixed;
- offer the dashboard from `vibe.get_status` -> `daemon.ui_url` so they can
  review it.

If `attention.available` is `false` with a reason mentioning `unreadable`, say
so — an unreadable trail is not a clean one.

If `remediation.rule_a_damage.detected` is true (also on
`vibe.get_remediation_audit` and the daemon summary `rule_a_damage`):

- tell the user Rule A **code damage** was recorded (build / test / resolve /
  lint-as-gate failure), with the per-pass `reason` and whether the workspace
  was rolled back;
- do not treat that pass as a successful fix even if some findings closed on
  the candidate;
- note that remedi ate **stops the loop** after demonstrated damage
  (`stopped_loop` / `rule_a_damage_stopped_loop`) so it does not rescan and
  damage-retry the same targets.

## MCP Tools

When the user asks what MCP exposes, summarize these tools:

- `vibe.get_posture`: Current security posture and ship verdict.
- `vibe.list_sessions`: Recent scan sessions for this workspace.
- `vibe.get_summary`: Actionable security summary.
- `vibe.get_findings`: Current finding set, including non-actionable issues.
- `vibe.get_status`: Combined daemon, setup, MCP, remediation, and proof state.
- `vibe.get_remediation_status`: Explicit remediation policy state.
- `vibe.get_compliance`: Read-only per-framework compliance evidence pack.
- `vibe.get_remediation_audit`: What was found, what the agent changed, what remained.
- `vibe.get_artifact_trust_status`: Signed-artifact trust posture and verification counts.
- `vibe.open_config`: Observe-only Doctor URL from MCP; use reachable: doctor --configure for changes.
- `vibe.doctor`: Redacted install/debug verdict and log pointers.
- `vibe.get_help`: Agent-safe MCP help payload.

Use the packaged command wrappers internally for execution, but keep user-facing
responses centered on `reachable: ...` commands rather than shell paths.

Version: 1.0.0b197
