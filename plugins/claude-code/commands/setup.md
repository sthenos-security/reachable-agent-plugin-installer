# reachable: setup

Purpose: install or verify the REACHABLE runtime for the current Claude Code
workspace, then wire supported local integrations.

Expected implementation path after marketplace install:

```text
reachable-plugin-bootstrap setup --agent claude_code --workspace <current-workspace>
```

Beta fallback if the setup adapter is missing:

```bash
curl -fsSL https://sthenosec.com/download/plugins/install.sh | bash -s -- --agent claude-code
```

Setup must not start a baseline scan or remediation automatically.
