#!/usr/bin/env sh
set -eu
cat <<'EOF'
reachable connects your coding agent to the local reachable scanner.
This installed plugin installer package gives the agent a reachable: setup command.
Full runtime install, workspace wiring, scanner checks, and MCP setup happen
only after you run reachable: setup from the agent.

reachable: setup
  Install or update reachable and wire this workspace.

reachable: doctor
  Show a concise health verdict, setup state, MCP status, and safe log pointers.
  To change tokens or policy, use reachable: doctor --configure.
  Open the remedi ate section to set signal families, the CI/CD workflow remedi ate
  lane, and workspace enable/disable. Local plugin policy is not the CI pipeline
  loop; both share the same pass-scoring rules.
  The local setup broker handles secrets; do not paste them into chat.

reachable: status
  Show the current workspace integration status in agent-safe form.

reachable: primer
  Show the advanced Vibe Primer for agent setup, token configuration, MCP tools,
  remediation policy, cleanup, and terminal support references.

reachable: remediation status
  Show whether remediation is disabled, enabled, running, or blocked.

reachable: remediation enable
  Enable the local remediation policy for future eligible agent events or
  explicit remediation runs. This does not start a scan immediately.

reachable: remediation disable
  Disable local remediation policy immediately. This does not remove runtime,
  scan history, or plugin setup.

reachable: proof status
  Show MCP proof and verification state for this workspace.

reachable: open dashboard
  Open the local dashboard.

reachable: uninstall
  Remove REACHABLE-managed agent wiring, MCP registration, and workspace setup.
  Runtime/cache/log removal stays explicit.

reachable: prune
  Clean orphaned REACHABLE-managed plugin files after a host uninstall or stale
  upgrade.

MCP tools
  vibe.get_posture                Current security posture and ship verdict
  vibe.list_sessions              Recent scan sessions for this workspace
  vibe.get_summary                Actionable security summary
  vibe.get_findings               Current finding set, including non-actionable issues
  vibe.get_status                 Combined daemon, setup, MCP, remediation, and proof state
  vibe.get_remediation_status     Explicit remediation policy state
  vibe.get_compliance             Read-only per-framework compliance evidence pack
  vibe.get_remediation_audit      What was found, what the agent changed, what remained
  vibe.get_artifact_trust_status  Signed-artifact trust posture and verification counts
  vibe.open_config                Observe-only Doctor URL from MCP; use reachable: doctor --configure for changes
  vibe.doctor                     Redacted install/debug verdict and log pointers
  vibe.get_help                   Agent-safe MCP help payload
EOF
