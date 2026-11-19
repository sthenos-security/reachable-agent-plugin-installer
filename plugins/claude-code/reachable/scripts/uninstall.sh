#!/usr/bin/env sh
set -eu
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ -n "${REACHABLE_HOME:-}" ]; then
  if [ -z "${HOME:-}" ]; then
    echo "REACHABLE_HOME is set but HOME is empty; cannot determine agent config home for reachable setup." >&2
    exit 1
  fi
  reachable_home="${REACHABLE_HOME}"
fi
if [ -z "${REACHABLE_HOME:-}" ]; then
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
if [ -z "$reachctl_bin" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "REACHABLE runtime is missing, and python3 is not installed, so uninstall cannot run; no files were removed. Install python3, then retry uninstall." >&2
    exit 1
  fi
  REACHABLE_HOME="$reachable_home" exec python3 -I "$script_dir/uninstall_core.py" --workspace "$workspace" "$@"
fi
exec "$reachctl_bin" vibe uninstall --full --workspace "$workspace" "$@"
