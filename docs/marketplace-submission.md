# Marketplace Submission

This repo is the GitHub-backed source for agent marketplace submissions.

Use one repo with one installable package per agent. Do not submit a single
universal plugin artifact across Claude Code, Cursor, and Codex.

Each submission must back-reference:

- official site: https://sthenosec.com;
- front-end release manifest: https://sthenosec.com/download/manifest.json;
- front-end plugin installer: https://sthenosec.com/download/plugins/install.sh;
- release provenance: Sthenos Security release pipeline metadata.

The plugin repo should link to the front-end download path. It should not copy
or fork the plugin downloader. Setup verification must anchor to signed release
metadata, checksums, cosign, and provenance.

## Claude Code

Submit the root `.claude-plugin/marketplace.json` marketplace and the
`plugins/claude-code` package when Claude marketplace requirements are
satisfied. The package must remain a setup wrapper. It does not bundle MCP
runtime code.

## Cursor

Submit the root `.cursor-plugin/marketplace.json` marketplace and the
`plugins/cursor` package when Cursor marketplace or directory requirements are
satisfied. If the marketplace requires install-time MCP execution, block
submission rather than adding a fake MCP server.

## Codex

Submit the root `.agents/plugins/marketplace.json` marketplace and the
`plugins/codex` package when Codex plugin marketplace requirements are
satisfied. The `.codex-plugin/plugin.json` manifest must stay within supported
Codex plugin fields.

## GitHub

Use GitHub topics, releases, README metadata, and search indexing for discovery.
GitHub Marketplace is not the primary AI-agent plugin directory. The existing
REACHABLE GitHub Action listing should cross-link here for users who want
agent-side setup.
