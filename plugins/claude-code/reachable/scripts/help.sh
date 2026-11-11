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
reachable: uninstall          remove Reachable from this computer
reachable: prune              clean up Reachable files left behind by an agent uninstall
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
# No runtime: Reachable isn't installed. A runtime that fails says why; it
# used to be hidden and reported as "isn't set up" (audit 2026-11-04).
if [ -z "$reachctl_bin" ]; then
  app_line="App: Reachable isn't set up for this folder yet. Say \`reachable: setup\`."
elif action_out="$("$reachctl_bin" vibe action --workspace "$workspace" 2>&1)" && [ -n "$action_out" ]; then
  app_line="$(printf '%s\n' "$action_out" | head -n 1)"
else
  app_line="App: Reachable couldn't read this folder's setting ($(printf '%s' "$action_out" | tail -n 1)). Say \`reachable: doctor\`."
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
