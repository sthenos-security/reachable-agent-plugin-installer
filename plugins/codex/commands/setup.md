# reachable: setup

Purpose: install or verify the REACHABLE runtime for the current Codex
workspace, then wire supported local integrations.

Expected implementation path after marketplace install:

```text
reachable-plugin-bootstrap setup --agent codex --workspace <current-workspace>
```

Beta fallback if the setup adapter is missing:

```bash
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent codex
```

Setup must not start a baseline scan or remediation automatically.
