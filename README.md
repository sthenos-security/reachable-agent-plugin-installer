# REACHABLE Agent Plugin Installer

This repository is the public framework for REACHABLE agent marketplace
plugins. It contains one catalog repo with one installable package per agent:
Claude Code, Cursor, and Codex.

It contains marketplace metadata, host-shaped plugin manifests, bootstrap
skills, setup commands, MCP descriptions, and publication docs.

It does not contain REACHABLE scanner, verifier, remediation, daemon, or MCP
runtime code.

Official site: https://sthenosec.com

REACHABLE product page and downloads are served from the Sthenos Security front
end. This repository is the public marketplace/source catalog that points users
back to that product UX.

Installers should download through `sthenosec.com`. `reach-core` is private,
and `reach-dist` is a public archive but not the customer-facing distribution
endpoint because direct GitHub downloads can hit throttling and UX limits.

The trust anchor is the signed release metadata exposed through the public
route. The release pipeline records build/signing provenance; GitHub repos are
provenance/archive references, not the primary install URLs.

## Install Flow

```text
Install the REACHABLE plugin from the agent marketplace
  -> open the target workspace
  -> run reachable: setup
  -> run reachable: doctor
```

`reachable: setup` installs or verifies the signed REACHABLE runtime for the
current workspace, then configures the local daemon-backed MCP server named
`reachable` where the agent supports MCP.

## What This Repo Publishes

- Plugin metadata for Claude Code, Cursor, and Codex.
- One installable package per agent, shaped for that agent marketplace.
- Bootstrap skills that expose `reachable: setup` and `reachable: doctor`.
- Descriptive MCP metadata for the server installed after setup.
- Marketplace submission docs and proof checklists.

## What This Repo Does Not Publish

- No scanner logic.
- No verifier logic.
- No remediation logic.
- No local daemon implementation.
- No bundled MCP server.
- No fake MCP server placeholder.

Runtime code is delivered by the signed REACHABLE installer and release
manifest.

## Release Binding And Provenance

This repo links to the public REACHABLE front-end download path. It does not
copy the plugin downloader or runtime artifacts.

```text
Manifest:  https://sthenosec.com/download/manifest.json
Installer: https://sthenosec.com/download/plugins/install.sh
```

The setup flow must verify:

- versioned release manifest;
- artifact SHA-256 checksums;
- cosign signature/bundle;
- GitHub Actions OIDC issuer identity;
- Sthenos Security release workflow identity;
- expected repository provenance for generated artifacts;
- expected release archive provenance when present.

If signature, checksum, issuer, identity, or provenance verification fails,
setup must fail closed.

## Direct Bootstrap Fallback

Marketplace install is the preferred UX. During beta or recovery, use the public
installer for the target agent:

```bash
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent codex
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent cursor
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent claude-code
```

After the installer package is present, open the workspace in the agent and run:

```text
reachable: setup
reachable: doctor
```

## Repository Layout

```text
marketplace.json
.claude-plugin/marketplace.json
.cursor-plugin/marketplace.json
.agents/plugins/marketplace.json
schemas/marketplace.schema.json
docs/
  release-binding.md
plugins/
  claude-code/
  cursor/
  codex/
```

Each plugin folder is intentionally thin. The plugin provides setup and doctor
instructions; the REACHABLE runtime owns security analysis and proof.

The repo is shared, but the installable artifacts are per-agent. Do not force a
single universal plugin package across Claude Code, Cursor, and Codex.

## Copyright And License

Copyright 2026 Sthenos Security.

This public framework repo is licensed under Apache-2.0. REACHABLE product
names, service marks, hosted services, and runtime release channels remain
subject to Sthenos Security terms.
