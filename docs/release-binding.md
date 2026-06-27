# Release Binding

This repository does not copy or vendor the REACHABLE plugin downloader.

The public user-facing download path is the Sthenos Security front end:

```text
Frontend:  https://sthenosec.com
Manifest:  https://sthenosec.com/download/manifest.json
Installer: https://sthenosec.com/download/plugins/install.sh
```

Installers should download from `sthenosec.com`, not from `reach-core` or
`reach-dist` directly. `reach-core` is private, and `reach-dist` is a public
artifact archive but is not the customer-facing distribution endpoint because
direct GitHub asset downloads can hit throttling and UX limits.

The trust anchor is the signed release metadata exposed through the public
route. That metadata is produced by the REACHABLE release pipeline and carries
the build/signing provenance. `reach-core` and `reach-dist` are provenance and
archive references, not primary install URLs.

## Why Link Instead Of Copy

Copying installer scripts into this repository would create a second mutable
trust root. It would also make beta/latest promotion ambiguous.

The correct model is:

```text
marketplace repo
  -> describes the plugin and setup commands
  -> points users to the public front-end download path
  -> never owns runtime download selection

sthenosec.com front end
  -> serves or resolves latest/beta manifest
  -> serves or resolves installer
  -> is the supported public download endpoint

reach-core
  -> builds release artifacts
  -> signs artifacts and manifests through the release workflow identity
  -> is private and not an install source

reach-dist
  -> archives immutable release artifacts
  -> may be referenced by provenance metadata
  -> is not the primary install source
```

## Verification Contract

`reachable: setup` must verify before executing downloaded runtime artifacts:

- release manifest authenticity;
- artifact SHA-256 checksums;
- cosign bundle/signature;
- GitHub Actions OIDC issuer:
  `https://token.actions.githubusercontent.com`;
- certificate identity matching the Sthenos Security REACHABLE release workflow;
- expected publisher: Sthenos Security;
- expected repository identity for runtime artifacts:
  `https://github.com/sthenos-security/reach-core/*`.
- expected release provenance or archive references when present.

If any check fails, setup must fail closed.

## Beta And Latest

The marketplace repo should not hard-code a beta artifact filename. It should
reference the front-end download path and verify the signed release manifest.
The release manifest decides the current beta/latest version and carries release
pipeline provenance.

Marketplace docs may say "uses the current REACHABLE beta release channel" only
when the manifest route is live and the installer verifies signatures and
checksums.
