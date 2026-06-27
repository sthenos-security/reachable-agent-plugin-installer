# Verify

Before calling a marketplace listing ready, prove the exact user-facing flow:

```text
Install plugin
  -> open workspace
  -> reachable: setup
  -> reachable: doctor
```

Required proof:

- the plugin is visible in the target agent;
- `reachable: setup` is accepted by the target agent;
- setup resolves the signed REACHABLE release manifest;
- runtime install or verification succeeds;
- checksum, cosign, issuer, certificate identity, and repository provenance
  verification succeeded;
- the release artifact resolves to expected archive identity or digest when
  present;
- the current workspace is wired;
- `reachable: doctor` reports a clear verdict;
- MCP is reported as configured only after setup;
- uninstall or repair touches only REACHABLE-managed files.

Static manifest checks, package smoke tests, and MCP config shape checks are
prerequisites. They are not enough to call an agent marketplace listing ready.
