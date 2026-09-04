#!/usr/bin/env sh
set -eu
cat <<'EOF'
REACHABLE VIBE PRIMER
=====================

Use this primer when you want the advanced technical view of REACHABLE inside a
coding agent. For the normal path, use:

1. reachable: setup
2. reachable: doctor
3. reachable: doctor --configure

SETUP MODEL
-----------

The installed agent package is a thin setup adapter. It does not scan by itself.
When you run reachable: setup, REACHABLE installs or updates the local runtime,
wires this workspace, starts the local daemon, configures MCP where supported,
and leaves baseline scans and remediation opt-in.

CONFIGURATION
-------------

Use reachable: doctor --configure to open the local browser broker for:

- REACHABLE API token
- GitHub token for source and PR context
- AI provider keys for better reachability and remediation quality
- scanner controls
- remediation policy

Do not paste secrets into agent chat. The broker stores credentials through the
local runtime and returns only redacted status to the agent.

AGENT COMMANDS
--------------

- reachable: help
- reachable: primer
- reachable: setup
- reachable: doctor
- reachable: doctor --configure
- reachable: status
- reachable: remediation status
- reachable: remediation enable
- reachable: remediation disable
- reachable: proof status
- reachable: open dashboard
- reachable: uninstall
- reachable: prune

reachable: remediation enable changes policy only. No scan is started by that
command; remediation applies on the next eligible agent event or explicit
remediation run.

MCP TOOLS
---------

- vibe.get_posture
- vibe.list_sessions
- vibe.get_summary
- vibe.get_findings
- vibe.get_status
- vibe.get_remediation_status
- vibe.get_compliance
- vibe.get_remediation_audit
- vibe.get_artifact_trust_status
- vibe.open_config
- vibe.doctor
- vibe.get_help

TERMINAL SUPPORT REFERENCES
---------------------------

These are host terminal references for operators and support. They are not the
normal in-agent next step.

- reachctl primer --vibe
- reachctl primer --tokens
- reachctl --help
- reachctl --advanced
- reachctl <command> --help

REACHABLE 1.0 beta
Copyright (c) 2026 Sthenos Security. All rights reserved.
EOF
