# REACHABLE agent plugin installer

Requires the REACHABLE runtime (installed by `reachable: setup` or the full
vibe install). This repository is the public marketplace catalog for REACHABLE:

- **Claude Code (M1):** `.claude-plugin/marketplace.json` → `plugins/claude-code/reachable`
- **Codex (M2):** `.agents/plugins/marketplace.json` → `plugins/codex/reachable`

Installing the plugin registers the local `reachable` MCP path and the
`reachable: setup` / `reachable: doctor` / `reachable: status` skills. It does
not contain the scanner.

This marketplace wrapper is not signature-gated. The trust boundary is the
signed release channel that `reachable: setup` pulls from
https://sthenosec.com/download.

Product download (vibe-coding default): https://sthenosec.com/download  
Standard SDLC / CI scanner-only: https://sthenosec.com/download/sdlc

## Download / install

### Claude Code

```sh
claude plugin marketplace add https://github.com/sthenos-security/reachable-agent-plugin-installer
claude plugin install reachable@sthenos-security
```

### Codex

```sh
codex plugin marketplace add https://github.com/sthenos-security/reachable-agent-plugin-installer
codex plugin add reachable@sthenos-security
```

### Cursor

Cursor's public marketplace requires an open-source plugin. Until that wrapper
decision, use the signed curl bootstrap:

```sh
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent cursor
```

### Full vibe runtime (optional terminal path)

Same continuous surface the plugin setup path installs:

```sh
curl -fsSL https://sthenosec.com/download/install.sh | bash
```

### Standard SDLC / CI (`--no-vibe`)

Scanner-only installs for pipelines and terminals (no daemon). Prefer the
dedicated page https://sthenosec.com/download/sdlc:

```sh
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --no-vibe
export PATH="$HOME/.reachable/venv/bin:$PATH"
reachctl scan /path/to/repo
```

### After the plugin

In the target workspace:

```text
reachable: setup
reachable: doctor
```

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

## Version

Plugin trees on `main` match the signed adapter for the current public release
(for example `1.0.0b178`). Content pins live in `reachable-skill-manifest.json`.
