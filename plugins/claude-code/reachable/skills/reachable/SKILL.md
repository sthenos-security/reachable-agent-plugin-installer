---
name: reachable
description: Use REACHABLE to set up, verify, and inspect local vibe-coding security remediation from Claude Code, and to enable, disable, or uninstall remediation for this workspace.
version: 1.0.0b166
---

# REACHABLE

Use this skill when a user asks Claude Code to set up REACHABLE, check install health,
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
- `reachable: setup`: install or update REACHABLE and wire this workspace.
  Marketplace install and beta curl install deliver this plugin installer
  package; they do not run the full runtime setup until the user asks from the
  agent.
- `reachable: doctor`: report the verdict plus summary fields. If the user asks
  to add, rotate, replace, or reconfigure tokens, run
  `reachable: doctor --configure` and open the credentials section in the local
  setup broker. The browser broker handles secrets and the chat receives only
  redacted status.
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

## MCP Tools

When the user asks what MCP exposes, summarize these tools:

- `vibe.get_status`: daemon, setup, MCP, remediation, and proof status.
- `vibe.get_posture`: current security posture and ship verdict.
- `vibe.list_sessions`: recent scan sessions for this workspace.
- `vibe.get_summary`: actionable security summary.
- `vibe.get_findings`: current finding set, including non-actionable issues.
- `vibe.get_config_status`: agent-safe setup and credential state.
- `vibe.get_agents`: detected local agents and MCP wiring state.
- `vibe.get_remediation_status`: remediation enablement and current policy.
- `vibe.get_remediation_audit`: auditor-readable record of the last run --
  findings before/after, per-iteration status, and the change set attributed
  to the agent.
- `vibe.get_dashboard_url`: local dashboard URL.
- `vibe.open_config`: observe-only Doctor URL from MCP; use
  `reachable: doctor --configure` for credential or policy changes.
- `vibe.doctor`: redacted install/debug verdict and log pointers.
- `vibe.get_help`: MCP-side help payload.

Use the packaged command wrappers internally for execution, but keep user-facing
responses centered on `reachable: ...` commands rather than shell paths.

Version: 1.0.0b166
