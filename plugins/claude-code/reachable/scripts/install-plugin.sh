#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
package_root="$(dirname "$script_dir")"
agent="claude_code"
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
target="${REACHABLE_CLAUDE_CODE_PLUGIN_DIR:-$HOME/.claude/plugins/reachable}"
if [ -z "${REACHABLE_CLAUDE_CODE_PLUGIN_DIR:-}" ]; then
  case "$target" in
    /tmp/*|/private/tmp/*|/var/folders/*)
      echo "Refusing to install reachable plugin installer into a temporary directory: $target" >&2
      exit 1
      ;;
  esac
fi
if [ ! -f "$package_root/reachable-plugin.json" ]; then
  echo "reachable plugin installer package metadata missing: $package_root/reachable-plugin.json" >&2
  exit 1
fi
rm -rf "$target"
mkdir -p "$(dirname "$target")"
cp -R "$package_root" "$target"
if [ ! -x "$target/scripts/setup.sh" ]; then
  chmod +x "$target/scripts/"*.sh 2>/dev/null || true
fi
if [ -x "$target/scripts/verify-content.sh" ]; then
  sh "$target/scripts/verify-content.sh" "$target"
fi
cat <<EOF
reachable plugin installer installed for $agent.
Location: $target
Workspace: $workspace

Next step: open the agent in this workspace and run:
  reachable: setup

Then verify with:
  reachable: doctor
EOF
