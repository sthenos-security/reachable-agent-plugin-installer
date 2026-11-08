---
name: reachable
description: Use REACHABLE to set up, verify, and inspect local vibe-coding security remediation from Claude Code, and to enable, disable, or uninstall remediation for this workspace.
version: 1.0.0b272
---

# REACHABLE

Use this skill when a user asks Claude Code to set up REACHABLE, check install health,
run doctor, inspect MCP wiring, open the local dashboard, review remediation
status, or turn remediation on or off for the current workspace.

Remediation can be turned off without removing anything: `reachable: remediation
disable` stops it for this workspace while leaving the runtime, scan history and
plugin setup in place. `reachable: uninstall` removes REACHABLE from this
workspace only; it stays installed on the machine. `reachable: uninstall --full`
removes it from the machine: agent plugins, MCP server, daemon, and
`~/.reachable` with scan history and credentials. Prefer these over telling the
user to delete files.

When the user asks to uninstall REACHABLE without saying which, ask before
running anything: "Remove it from this repo only, or from this machine
entirely? Entirely deletes your scan history and credentials." After the user
chose "entirely", `--full` first prints the list of what it will remove and
then stops: without a terminal it refuses until told `--export PATH` (a
.tar.gz of scan history and settings, no credentials) or `--no-export`. Show
the user that list, ask whether they want the export and where, then run
`reachable: uninstall --full --yes --export PATH` or
`reachable: uninstall --full --yes --no-export`, and tell them the REACHABLE
MCP server in this session stops when they restart the agent.

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
  `reachable: settings` and open the credentials section in the local
  setup broker when the installed runtime can open it. The browser broker
  handles secrets and the chat receives only redacted status. If opening fails,
  report the failure; do not claim a connection was saved or invent a host
  browser action. Browser confirmation cannot approve an initial install.
  For remediate policy, open the remediate section: workspace
  enable/disable, signal families (`vibe-remediation-signals`), and the CI/CD
  workflow remediate lane. Local plugin policy is vibe-coding consent; CI
  auto-remediate + Pages is the pipeline product loop. Deep remediate is a
  per-run noise-boundary opt-in, not a broker toggle.
- `reachable: status`: run the status wrapper and start your reply with its
  `answer` lines, exactly and in order; they say what Reachable is doing or
  found and the one thing to say next. Add details only when asked.
- `reachable: baseline show`: show the confirmed baseline branch and mode for
  this workspace.
- `reachable: baseline set`: record the repo baseline branch/mode.
- `reachable: baseline override`: set a per-clone baseline override.
- `reachable: open dashboard`: open the local dashboard.
- `reachable: action`: what Reachable does in this app, and the choices. Run
  the action wrapper with no argument and relay its output; its first line,
  "App: [path] · [setting]", is the first line of your answer.
- `reachable: action report`: just report; Reachable won't change the code
  ("just report"). Run the action wrapper with `report`.
- `reachable: action stop`: pause automatic checks and fixes ("stop"). Run the
  action wrapper with `stop`.
- `reachable: action start`: watch again ("start"). It starts no check and
  never turns fixing back on. Run the action wrapper with `start`.
- `reachable: action ask-first`: keep approving each fix ("keep asking"). Run
  the action wrapper with `ask-first`.
When setup's output says it couldn't open the settings page and asks the
question in chat, ask the user exactly that question. When they answer "fix"
or "just report", run the record-answer wrapper with `fix` or `report` and
relay its output. Never answer it for them.
- `reachable: action allow-fixes`: the user wants Reachable to fix ("allow
  fixes"). Run the action wrapper with `allow-fixes`: it opens Reachable's
  settings page, and the user turns fixing on there. Never say fixing is on
  until the setting line says so.
- `reachable: remediation status`: report explicit local remediation policy and
  run state.
- `reachable: remediation enable`: the same as `reachable: action allow-fixes`.
  Never run the remediation-enable wrapper yourself (AGENT-CLI-BOUNDARY §3.3).
  Do not claim this starts a scan.
- `reachable: remediation disable`: the same as `reachable: action report`.
- `reachable: cost`: what Reachable's checks have cost in AI, with the cost
  wrapper; relay its answer.
- `reachable: report a problem`: ask "What went wrong, in your own words?",
  then run the report wrapper with `--what "<their words>"`. Relay the summary
  of what it includes; only after the user says yes, run it again with
  `--confirmed` and give them the reference it prints.
- `reachable: open`: open the Reachable page (results and fixes) in the
  browser with the open wrapper.
- `reachable: settings`: open the Settings tab (AI and GitHub access, what
  Reachable does) with the settings wrapper. Keys are typed there, never in chat.
- `reachable: fix`: fix the problems Reachable found with the fix wrapper and
  relay its answer. If the app is set to report, it opens the Settings tab;
  only the user turns fixing on there.
- `reachable: check`: ask Reachable to check this app with the check wrapper
  and relay its answer. Never run a scan yourself; "scan", "check my app" and
  "is my app ok?" mean this command.
- `reachable: undo`: undo the last Reachable fix with the undo wrapper. If it
  says the user edited a fixed file since, relay its question exactly; only
  after the user says yes, run the undo wrapper again with `--confirmed`.
- `reachable: proof status`: report MCP proof status.
- `reachable: uninstall`: remove REACHABLE from this workspace only.
- `reachable: uninstall --full`: remove REACHABLE from this machine; it deletes
  scan history and credentials.
- `reachable: prune`: clean orphaned REACHABLE-managed plugin files after
  host/plugin uninstall.

These three remove REACHABLE, so the user runs them: do not run them yourself.
Give the user the exact command for their own terminal: `bash` and the full,
quoted path of this plugin's uninstall wrapper (add `--full` for `--full`), or
of its prune wrapper.

## Plain words

Users rarely type commands. Map what they mean (onboarding C30;
AGENT-CLI-BOUNDARY §5):

- "scan", "check my app", "is my app ok?": `reachable: check`.
- "what did it find?", "status": `reachable: status`.
- "fix it", "remediate": `reachable: fix`.
- "undo the Reachable fix", "my app broke after the fix": `reachable: undo`.
- "stop", "start", "just report": `reachable: action stop` / `start` / `report`;
  "allow fixes", "keep asking": `reachable: action allow-fixes` / `ask-first`.
- "add a key", "settings": `reachable: settings`.
- "something's broken", "I have a question": `reachable: report a problem`.
- "run reachctl …": give the exact command for their own terminal; don't run it.
- Anything else Reachable-sounding: `reachable: help`.

## Reachable's command line is the user's

Never run `reachctl`, `reachable` or `python -m reachable` yourself, in any
form, and don't look for their options. Reachable checks by itself as the agent
changes code. If the user asks you to run one, give them the exact command for
their own terminal. A shell command that runs Reachable is blocked by its hook.

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

Version: 1.0.0b272
