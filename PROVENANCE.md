# Provenance

This repository publishes framework metadata for agent marketplaces. Runtime
code is delivered separately by the REACHABLE public download route and release
pipeline:

```text
reach-core builds and signs
  -> reach-dist archives immutable artifacts
  -> sthenosec.com serves the product download UX
```

Installers should use `sthenosec.com` as the public download route. `reach-core`
is private, and `reach-dist` is a public archive/provenance surface rather than
the primary customer install endpoint.

Each published release should record:

- repository commit;
- release tag;
- plugin manifest digests;
- generated package digests if packages are attached;
- REACHABLE runtime release channel;
- signed release manifest URL;
- immutable archive URL or digest when present;
- publisher: Sthenos Security.

Marketplace submissions should link back to this repository and to the
corresponding signed REACHABLE release manifest.

## Runtime Verification

The marketplace plugin should not execute runtime artifacts until setup verifies
the public front-end download path and signed release provenance:

```text
https://sthenosec.com/download/manifest.json
https://sthenosec.com/download/plugins/install.sh
```

Required verification:

- SHA-256 checksum matches release metadata;
- cosign bundle/signature verifies;
- certificate OIDC issuer is `https://token.actions.githubusercontent.com`;
- certificate identity matches the Sthenos Security REACHABLE release workflow;
- runtime artifacts come from the expected Sthenos Security repository identity;
- archive metadata resolves to the expected release asset or digest when
  present.

The expected runtime artifact repository identity is:

```text
https://github.com/sthenos-security/reach-core/*
```

The marketplace repo itself is a public catalog. The front end provides the
user-facing download route. Release signing and artifact metadata provide the
source of truth for artifact identity and provenance.
