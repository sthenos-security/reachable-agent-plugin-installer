REACHABLE adapter for Codex

This wrapper is a thin plugin installer package. It does not contain scanner logic.
It installs the REACHABLE agent wrapper into the agent. Full runtime setup happens only when the user runs reachable: setup.

Preferred install:
1. Install REACHABLE from your agent marketplace and run reachable: setup.
2. For beta/manual install, run the REACHABLE curl bootstrap for your agent from the workspace; it installs this plugin installer package.
3. Then run reachable: setup inside the agent; reachable: doctor can verify setup afterward.

Browser zip download is debug/recovery only. It only saves the zip; it does not auto-install this package or register anything in your agent.

Public Codex store listing: not currently possible. OpenAI's plugin submission form does not allow local stdio MCP servers, which is the transport this plugin uses. Install from the repo/personal marketplace or with the curl bootstrap instead.
