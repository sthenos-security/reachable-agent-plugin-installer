---
name: reachable
description: Use REACHABLE to set up, show status, open Settings, or explain help for local vibe-coding security remediation from Claude Code.
version: 1.0.0b284
---

# REACHABLE

Use this skill when a user asks Claude Code to set up REACHABLE, show status,
open Settings, inspect Reachable evidence, or turn Reachable on or off for the
current workspace.

The user-facing surface is intentionally small. Setup, status, Settings, and
help are the only normal commands to offer. Settings controls keys and whether
Reachable may make changes; status shows what Reachable is doing and what it
found. Do not teach hidden wrapper names as shortcuts.

When `reachable: status` reports `setup.required` with `workspace_unregistered`,
the one next step is `reachable: setup` for this workspace; run it, then check
status again. `rules.generated: false` is not a setup problem: rules are
written by the first scan, and setup does not scan by default. Do not guess at
other causes (empty repo, missing git, missing API key) -- none of them affect
setup.

REACHABLE is the local source of truth. The plugin is a thin adapter. Do not
invent scanner results or edit REACHABLE configuration files directly.

## Task Authority

Classify the request before acting:

- REACHABLE command: if the user invokes `reachable: ...`, follow the packaged
  REACHABLE command path.
- REACHABLE evidence or remediation: if the request involves REACHABLE
  findings, reachability, exploitability, remediation policy, status,
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

**Offer the user only four commands: `reachable: setup`, `reachable: status`,
`reachable: settings` and `reachable: help`** (unified design Part A §5). Every
other packaged wrapper runs only as an internal compatibility path when the
user's own words ask for that behavior; never list it, suggest it, or tell the
user to type it.

- `reachable: setup`: install or update REACHABLE and wire this workspace,
  including Gate 1 FAST_TRACK skills for write-time prevention.
  Marketplace install and beta curl install deliver this plugin installer
  package; they do not run the full runtime setup until the user asks from the
  agent.
- `reachable: status`: run the status wrapper and start your reply with its
  `answer` lines, exactly and in order; they say what Reachable is doing or
  found and the one thing to say next. It opens the Results tab for this
  workspace. Add details only when asked.
- `reachable: settings`: open the Settings tab (AI and GitHub access, what
  Reachable does) with the settings wrapper. Keys are typed there, never in chat.

When setup's output says it couldn't open the settings page and asks the
question in chat, ask the user exactly that question. When they answer "fix"
or "just report", record that answer with the packaged answer path and relay
its output. Never answer it for them.

If the user asks to add, rotate, replace, or reconfigure tokens, run
`reachable: settings`; the Settings tab handles secrets and chat receives only
redacted status. If opening fails, report the failure; do not claim a
  connection was saved or invent a host browser action. Browser confirmation
  cannot approve an initial install.

If the user asks to scan, check the app, or run Reachable now, ask Reachable's
daemon through the packaged Scan now path and relay its answer. Never run a
scan yourself. The daemon runs the fast path first, then the scan (unified
design §7.3). The Results tab also has the Scan now button for the same flow.

## Plain words

Users rarely type commands. Map what they mean (onboarding C30;
AGENT-CLI-BOUNDARY §5):

- "scan", "scan now", "check my app", "is my app ok?": ask Reachable's daemon through the packaged Scan now path.
- "what did it find?", "status": `reachable: status`.
- "fix it", "remediate", "allow fixes", "keep asking": `reachable: settings`.
- "stop", "start", "turn Reachable off", "just report": `reachable: settings`.
- "add a key", "settings", "change tokens", "configure Reachable": `reachable: settings`.
- "something's broken", "I have a question": `reachable: status`, then explain the status output.
- "run reachctl …": give the exact command for their own terminal; don't run it.
- Anything else Reachable-sounding: `reachable: help`.

## Reachable's command line is the user's

Never run raw `reachctl`, `reachable` or `python -m reachable` yourself, in any
form, and don't look for their options. Reachable checks by itself as the agent
changes code. If the user asks you to run a raw CLI command, give them the
exact command for their own terminal.

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
- offer the Reachable page from `vibe.get_status` -> `daemon.ui_url` so they
  can review it.

If `attention.available` is `false` with a reason mentioning `unreadable`, say
so — an unreadable trail is not a clean one.

If `remediation.rule_a_damage.detected` is true (also on
`vibe.get_remediation_audit` and the daemon summary `rule_a_damage`):

- tell the user Rule A **code damage** was recorded (build / test / resolve /
  lint-as-gate failure), with the per-pass `reason` and whether the workspace
  was rolled back;
- do not treat that pass as a successful fix even if some findings closed on
  the candidate;
- note that remediate **stops the loop** after demonstrated damage
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
- `vibe.open_config`: Observe-only Doctor URL from MCP; use reachable: settings for changes.
- `vibe.doctor`: Redacted install/debug verdict and log pointers.
- `vibe.get_help`: Agent-safe MCP help payload.

Use the packaged command wrappers internally for execution, but keep user-facing
responses centered on `reachable: ...` commands rather than shell paths.

Version: 1.0.0b284
