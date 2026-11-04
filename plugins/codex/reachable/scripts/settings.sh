#!/usr/bin/env sh
set -eu
if [ "$#" -ne 0 ]; then
  echo "usage: settings.sh" >&2
  exit 2
fi
exec "$(dirname "$0")/doctor.sh" --configure
