---
name: reachable-bootstrap
description: "Bootstrap REACHABLE in a Codex workspace with reachable: setup, then verify with reachable: doctor."
---

# REACHABLE Bootstrap

Use this skill when the user asks for `reachable: setup`, `reachable: doctor`,
or REACHABLE workspace setup from Codex.

## Contract

The plugin is a setup adapter only. It does not contain scanner, verifier,
remediation, daemon, or MCP runtime code.

When the user asks for `reachable: setup`:

1. Confirm the current workspace path.
2. Run the signed REACHABLE plugin bootstrap for Codex.
3. Let setup install or verify the REACHABLE runtime.
4. Let setup configure the local MCP server named `reachable` where supported.
5. Tell the user to run `reachable: doctor` when setup completes.

When the user asks for `reachable: doctor`:

1. Run the REACHABLE doctor command exposed by setup.
2. Report the verdict, required action, and whether MCP is configured.
3. Do not claim risk reduction unless REACHABLE validation or rescan evidence
   exists.

Do not ask for provider tokens in chat. Sensitive setup belongs in the local
doctor or setup broker flow.
