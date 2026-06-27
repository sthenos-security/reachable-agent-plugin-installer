# Install

Preferred UX:

```text
Install REACHABLE from the agent marketplace
  -> open the target workspace
  -> run reachable: setup
  -> run reachable: doctor
```

During beta or recovery, install the setup adapter directly:

```bash
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent codex
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent cursor
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent claude-code
```

This installs the bootstrap adapter only. Runtime setup happens after the user
runs `reachable: setup` inside the agent workspace.

Do not copy installer code from this repository. The setup adapter uses the
Sthenos Security front-end download path:

```text
https://sthenosec.com/download/manifest.json
https://sthenosec.com/download/plugins/install.sh
```

Setup must verify version, checksum, cosign signature/bundle, issuer identity,
repository provenance, release archive provenance when present, and publisher
before executing runtime artifacts.
