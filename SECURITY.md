# Security

This repository is a metadata and bootstrap framework. It does not ship the
REACHABLE runtime, scanner, verifier, remediation engine, local daemon, or MCP
server.

## Trust Boundary

Runtime installation is handled by the signed REACHABLE installer and release
manifest. Marketplace plugin files only expose setup and doctor instructions.

`reachable: setup` must verify release metadata before installing or updating
runtime components. It must not silently install arbitrary code from mutable
URLs.

The setup flow must fail closed when checksum, cosign, issuer, certificate
identity, repository provenance, or publisher checks fail.

The marketplace repo links to the public front-end download path instead of
copying installer code:

```text
https://sthenosec.com/download/manifest.json
https://sthenosec.com/download/plugins/install.sh
```

Those routes are the supported public install endpoint. Verification anchors on
signed artifact identity and release provenance, not on trusting the front end
alone.

## Secrets

Do not put API tokens, provider credentials, local daemon tokens, private
workspace data, or raw agent transcripts in this repository.

Sensitive configuration belongs in the local REACHABLE doctor or setup broker
flow.

## Reporting Issues

Report security issues to Sthenos Security through the published security
contact for the REACHABLE product. Do not open public issues containing secrets,
customer data, or exploit details.
