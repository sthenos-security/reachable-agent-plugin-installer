#!/usr/bin/env sh
set -eu
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != "more" ]; }; then
  echo "usage: help.sh [more]" >&2
  exit 2
fi
if [ "${1:-}" = "more" ]; then
cat <<'EOF'
reachable: doctor             check that Reachable itself is working
reachable: uninstall          remove Reachable from this app (add --full for this computer)
reachable: prune              clean up Reachable files left behind by an agent uninstall

Older names still work: open dashboard, doctor --configure, remediation enable,
remediation disable.

MCP tools
  vibe.get_posture                Current security posture and ship verdict
  vibe.list_sessions              Recent scan sessions for this workspace
  vibe.get_summary                Actionable security summary
  vibe.get_findings               Current finding set, including non-actionable issues
  vibe.get_status                 Combined daemon, setup, MCP, remediation, and proof state
  vibe.get_remediation_status     Explicit remediation policy state
  vibe.get_compliance             Read-only per-framework compliance evidence pack
  vibe.get_remediation_audit      What was found, what the agent changed, what remained
  vibe.get_artifact_trust_status  Signed-artifact trust posture and verification counts
  vibe.open_config                Observe-only Doctor URL from MCP; use reachable: doctor --configure for changes
  vibe.doctor                     Redacted install/debug verdict and log pointers
  vibe.get_help                   Agent-safe MCP help payload
EOF
  exit 0
fi
reachable_user_home=""
reachable_uid="$(/usr/bin/id -u 2>/dev/null || id -u 2>/dev/null || true)"
reachable_user="$(/usr/bin/id -un 2>/dev/null || id -un 2>/dev/null || true)"
if [ -n "$reachable_uid" ] && [ -x /usr/bin/getent ]; then
  reachable_user_home="$(/usr/bin/getent passwd "$reachable_uid" | /usr/bin/awk -F: '{print $6}' || true)"
fi
if [ -z "$reachable_user_home" ] && [ -n "$reachable_uid" ] && [ -x /bin/getent ]; then
  reachable_user_home="$(/bin/getent passwd "$reachable_uid" | /usr/bin/awk -F: '{print $6}' || true)"
fi
if [ -z "$reachable_user_home" ] && [ -n "$reachable_user" ] && [ -x /usr/bin/dscl ]; then
  reachable_user_home="$(/usr/bin/dscl . -read "/Users/$reachable_user" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}' || true)"
fi
if [ -z "$reachable_user_home" ]; then
  echo "Could not determine the OS account home for reachable setup." >&2
  exit 1
fi
case "$reachable_user_home" in
  /tmp/*|/private/tmp/*|/var/folders/*)
    echo "Refusing to install reachable into a temporary HOME: $reachable_user_home" >&2
    exit 1
    ;;
esac
HOME="$reachable_user_home"
export HOME
if [ -n "${REACHABLE_HOME:-}" ]; then
  reachable_home="${REACHABLE_HOME}"
else
  reachable_home="$HOME/.reachable"
fi
if [ -z "${PYTHON:-}" ] && [ -x "$reachable_home/venv/bin/python" ]; then
  PYTHON="$reachable_home/venv/bin/python"
  export PYTHON
fi
reachctl_bin="${REACHABLE_REACHCTL_BIN:-}"
if [ -n "$reachctl_bin" ]; then
  if ! "$reachctl_bin" --version >/dev/null 2>&1; then
    echo "Configured REACHABLE CLI is not healthy: $reachctl_bin" >&2
    exit 1
  fi
elif [ -x "$reachable_home/venv/bin/reachctl" ]; then
  if "$reachable_home/venv/bin/reachctl" --version >/dev/null 2>&1; then
    reachctl_bin="$reachable_home/venv/bin/reachctl"
  fi
fi
app_line=""
if [ -n "$reachctl_bin" ]; then
  app_line="$("$reachctl_bin" vibe action --workspace "$workspace" 2>/dev/null | head -n 1)" || app_line=""
fi
if [ -z "$app_line" ]; then
  app_line="App: Reachable isn't set up for this folder yet. Say \`reachable: setup\`."
fi
cat <<'EOF'
Reachable makes your agent write safer code, checks your app by itself,
and can fix what it finds. Your code stays on this computer unless an AI
key or a Reachable account is connected; `reachable: settings` shows which.
EOF
echo ""
echo "$app_line"
echo ""
cat <<'EOF'
reachable: status             what it found and fixed, and what it's doing now
reachable: fix                fix the problems it found
reachable: undo               undo the last Reachable fix
reachable: check              check now, or as soon as it can
reachable: action             allow-fixes, report, stop or start
reachable: open               see results and fixes in your browser
reachable: settings           add AI or GitHub access, change what it does
reachable: cost               what checks and fixes have cost
reachable: report a problem   something not working, or a question

More: reachable: help more
EOF
