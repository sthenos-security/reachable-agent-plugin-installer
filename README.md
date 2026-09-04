# REACHABLE for Claude Code

Requires the REACHABLE runtime, already installed and licensed. This repository
is the Claude Code marketplace catalog. Installing the plugin here registers
the local `reachable` MCP server and the `reachable: setup` / `reachable: doctor`
/ `reachable: status` skills. It does not contain the scanner.

This marketplace wrapper is not signature-gated. The trust boundary is the
signed release channel that `reachable: setup` pulls from
https://sthenosec.com/download.

## Install

```sh
claude plugin marketplace add https://github.com/sthenos-security/reachable-agent-plugin-installer
claude plugin install reachable@sthenos-security
```

Then, in the target workspace, run `reachable: setup`. Use `reachable: doctor`
to verify.

## What the MCP server does

All MCP tools report on state a prior REACHABLE run produced. There is no
scan-through-MCP tool. There is no OAuth account; REACHABLE is bring-your-own-token.

The tools:

- `vibe.get_posture` — Current security posture and ship verdict
- `vibe.list_sessions` — Recent scan sessions for this workspace
- `vibe.get_summary` — Actionable security summary
- `vibe.get_findings` — Current finding set, including non-actionable issues
- `vibe.get_status` — Combined daemon, setup, MCP, remediation, and proof state
- `vibe.get_remediation_status` — Explicit remediation policy state
- `vibe.get_compliance` — Read-only per-framework compliance evidence pack
- `vibe.get_remediation_audit` — What was found, what the agent changed, what remained
- `vibe.get_artifact_trust_status` — Signed-artifact trust posture and verification counts
- `vibe.open_config` — Observe-only Doctor URL from MCP; use reachable: doctor --configure for changes
- `vibe.doctor` — Redacted install/debug verdict and log pointers
- `vibe.get_help` — Agent-safe MCP help payload

`vibe.open_config` is the one non-pure-reader. It opens an observe-only Doctor URL.
Use `reachable: doctor --configure` for changes.

## Cursor and Codex

This catalog is the Claude Code marketplace (M1). Cursor's public marketplace
requires an open-source plugin; Codex's public directory does not accept local
stdio MCP. Those hosts install via:

```sh
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent cursor
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent codex
```

Then run `reachable: setup` in the agent.
