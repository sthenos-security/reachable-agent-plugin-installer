#!/usr/bin/env sh
set -eu
if [ "$#" -ne 0 ]; then
  echo "usage: settings.sh" >&2
  exit 2
fi
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
reachable_home="${REACHABLE_HOME:-$HOME/.reachable}"
reachctl_bin="$reachable_home/venv/bin/reachctl"
if [ -n "${REACHABLE_REACHCTL_BIN:-}" ]; then
  reachctl_bin="$REACHABLE_REACHCTL_BIN"
fi
if [ ! -x "$reachctl_bin" ]; then
  echo "REACHABLE CLI not found. Run setup first." >&2
  exit 1
fi
exec "$reachctl_bin" vibe setup open --workspace "$workspace" --source plugin --reason settings --section credentials --json-output
