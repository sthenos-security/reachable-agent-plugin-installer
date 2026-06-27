---
name: reachable-bootstrap
description: "Bootstrap REACHABLE in a Cursor workspace with reachable: setup, then verify with reachable: doctor."
---

# REACHABLE Bootstrap

Use this skill when the user asks for `reachable: setup`, `reachable: doctor`,
or REACHABLE workspace setup from Cursor.

This plugin is a setup adapter only. Runtime, MCP, scanner, verifier, and
remediation code are installed or verified by the signed REACHABLE setup flow.

For `reachable: setup`, run the REACHABLE setup bootstrap for Cursor and the
current workspace. Setup may configure the local daemon-backed MCP server named
`reachable` after the runtime is verified.

For `reachable: doctor`, report the setup verdict and next action. Do not claim
security risk was reduced unless REACHABLE validation or rescan evidence exists.
