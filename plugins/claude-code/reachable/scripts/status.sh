#!/usr/bin/env sh
set -eu
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
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
bootstrap_bin="${REACHABLE_BOOTSTRAP_BIN:-}"
if [ -n "$bootstrap_bin" ]; then
  if ! "$bootstrap_bin" --help >/dev/null 2>&1; then
    echo "Configured REACHABLE bootstrap is not healthy: $bootstrap_bin" >&2
    exit 1
  fi
elif [ -z "${REACHABLE_REACHCTL_BIN:-}" ] && [ -x "$reachable_home/venv/bin/reachable-plugin-bootstrap" ]; then
  if "$reachable_home/venv/bin/reachable-plugin-bootstrap" --help >/dev/null 2>&1; then
    bootstrap_bin="$reachable_home/venv/bin/reachable-plugin-bootstrap"
  fi
fi
if [ -n "$bootstrap_bin" ]; then
  exec "$bootstrap_bin" status --agent claude_code --workspace "$workspace" "$@"
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
if [ -z "$reachctl_bin" ]; then
  echo "REACHABLE CLI not found. Run setup first." >&2
  exit 1
fi
exec "$reachctl_bin" vibe status --workspace "$workspace" --json-output "$@"
