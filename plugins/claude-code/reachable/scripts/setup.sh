#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
package_root="$(dirname "$script_dir")"
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
# The IMMUTABLE per-version asset, never the mutable front door.
#
# This plugin pins the SHA-384 of one exact install.sh. `/download/install.sh`
# changes whenever reach-dist changes it -- measured 2026-10-14: 93 commits
# since January, 7 in the last 90 days -- so pinning against it would break
# every already-installed plugin on each installer change, and plugins update
# lazily through marketplaces. The versioned release asset never changes, so
# the pin always matches.
#
# This does NOT freeze the runtime. install.sh is run with --update and no
# --version, so it resolves "latest" from the signed release manifest and
# installs the newest wheel. The installer stays at this plugin's version; the
# product does not. Updating the plugin is only needed to get a newer INSTALLER.
installer_url="${REACHABLE_INSTALLER_URL:-https://github.com/sthenos-security/reach-dist/releases/download/v1.0.0b250/install.sh}"
release_manifest_url="${REACHABLE_RELEASE_MANIFEST_URL:-https://sthenosec.com/download/manifest.json}"
installer_sha384="05726a98b1c1b82f1516864de8099522adedf61b90ce5cff630c70424ca7c58c3f1ebcee00e41cc26b9e700b10422fed"
verify_plugin_installer="${REACHABLE_VERIFY_PLUGIN_INSTALLER:-1}"
release_selector="${REACHABLE_RELEASE_SELECTOR:-latest}"
local_wheel="${REACHABLE_LOCAL_WHEEL:-}"
bootstrap_install_args="--skip-install"
curl_connect_timeout="${REACH_LLM_CONNECT_TIMEOUT:-5}"
curl_archive_timeout="${REACH_HTTP_ARCHIVE_DOWNLOAD_TIMEOUT:-60}"
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
if [ "$verify_plugin_installer" != "0" ]; then
  metadata="$package_root/reachable-plugin.json"
  marker="$package_root/.reachable-plugin-installer.json"
  if [ ! -f "$metadata" ]; then
    echo "REACHABLE plugin installer metadata is missing: $metadata" >&2
    exit 1
  fi
  metadata_agent="$(sed -n 's/.*"agent"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata" | head -n 1 | tr '_' '-')"
  metadata_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata" | head -n 1)"
  if [ "$metadata_agent" != "claude-code" ]; then
    echo "REACHABLE plugin installer agent mismatch: expected claude-code, got $metadata_agent" >&2
    exit 1
  fi
  if [ -z "$metadata_version" ]; then
    echo "REACHABLE plugin installer version is missing in $metadata" >&2
    exit 1
  fi
  if [ -f "$marker" ]; then
    marker_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$marker" | head -n 1)"
    marker_signature="$(sed -n 's/.*"signature_bundle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$marker" | head -n 1)"
    if [ "$marker_version" != "$metadata_version" ]; then
      echo "REACHABLE plugin installer marker version mismatch: expected $metadata_version, got $marker_version" >&2
      exit 1
    fi
    if [ -z "$marker_signature" ]; then
      echo "REACHABLE plugin installer marker is missing signature bundle provenance" >&2
      exit 1
    fi
  elif [ "${REACHABLE_REQUIRE_PLUGIN_PROVENANCE:-0}" = "1" ]; then
    echo "REACHABLE plugin installer provenance marker is missing. Reinstall from the signed curl installer or verified marketplace." >&2
    exit 1
  fi
fi
tmp="$(mktemp "${TMPDIR:-/tmp}/reachable-install.XXXXXX")"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT
curl -fsSL --connect-timeout "$curl_connect_timeout" --max-time "$curl_archive_timeout" "$installer_url" -o "$tmp"
# --- L1: verify install.sh by digest, not by signature --------------------
#
# The key, the verifier and this script all arrive in the SAME unverified plugin
# package, so a signature check against a key from that package buys nothing a
# digest does not. The digest instead:
#   * defends CDN and release tampering equally,
#   * prevents rollback equally -- an exact digest is an exact version,
#   * is immune to signing-key theft,
#   * needs only a hash tool: no Python, no venv, no network, no sudo,
#   * behaves identically in CI/CD, on a desktop and on a node.
# install.sh then does the signed-manifest work, where a real verifier exists.
#
# SHA-384 because that is what CNSA 1.0 specifies and what `openssl dgst` runs
# through the host's validated module in FIPS mode.
if [ -z "$installer_sha384" ]; then
  echo "This REACHABLE plugin package was built without an installer digest." >&2
  echo "It cannot verify the installer, so it refuses to run it." >&2
  echo "Reinstall the plugin from the signed marketplace release." >&2
  exit 1
fi
installer_actual=""
if command -v openssl >/dev/null 2>&1; then
  # Preferred: on a FIPS host this runs in the validated module.
  installer_actual="$(openssl dgst -sha384 "$tmp" 2>/dev/null | awk '{print $NF}')"
elif command -v sha384sum >/dev/null 2>&1; then
  installer_actual="$(sha384sum "$tmp" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  installer_actual="$(shasum -a 384 "$tmp" | awk '{print $1}')"
fi
if [ -z "$installer_actual" ]; then
  echo "REACHABLE cannot verify the installer: no SHA-384 tool was found." >&2
  echo "Install one, then re-run setup:" >&2
  echo "  Debian/Ubuntu:  sudo apt-get install -y openssl" >&2
  echo "  Fedora/RHEL:    sudo dnf install -y openssl" >&2
  echo "  Alpine:         sudo apk add openssl" >&2
  echo "  macOS:          shasum ships with macOS; check your PATH" >&2
  exit 1
fi
if [ "$installer_actual" != "$installer_sha384" ]; then
  # Three different causes land here and they need different actions, so the
  # message names all three instead of asserting the alarming one. Measured
  # 2026-10-14: sthenosec.com returns its SPA index page with HTTP 200 for any
  # missing path, and `curl -f` does NOT fail on that -- so "the URL is wrong"
  # is a routine way to reach this branch, not an exotic one.
  echo "REACHABLE installer does not match what this plugin was built against." >&2
  echo "  expected $installer_sha384" >&2
  echo "  received $installer_actual" >&2
  echo "" >&2
  if head -c 64 "$tmp" | grep -qiE "<!doctype html|<html"; then
    echo "The download is an HTML page, not a shell script. The installer URL is" >&2
    echo "wrong or is being intercepted by a proxy or captive portal:" >&2
    echo "  $installer_url" >&2
  else
    echo "Most likely, in order:" >&2
    echo "  1. This plugin is out of date and the installer has moved on." >&2
    echo "     Update the plugin, then re-run setup." >&2
    echo "  2. A proxy or CDN served something other than the real installer." >&2
    echo "  3. The installer was tampered with." >&2
  fi
  echo "" >&2
  echo "Setup stops here either way. It will not run an installer it cannot verify." >&2
  exit 1
fi
export REACHABLE_INSTALLER_AGENT_SETUP="${REACHABLE_INSTALLER_AGENT_SETUP:-1}"
export REACHABLE_INSTALLER_SUMMARY="${REACHABLE_INSTALLER_SUMMARY:-compact}"
export REACHABLE_INSTALL_PROGRESS_INTERVAL="${REACHABLE_INSTALL_PROGRESS_INTERVAL:-60}"
if [ -n "$local_wheel" ]; then
  if [ "$release_selector" != "latest" ]; then
    echo "REACHABLE_LOCAL_WHEEL cannot be combined with REACHABLE_RELEASE_SELECTOR=$release_selector" >&2
    exit 1
  fi
  bash "$tmp" --update --vibe --agent claude_code --repo "$workspace" --no-baseline --wheel "$local_wheel"
elif [ "$release_selector" != "latest" ]; then
  bash "$tmp" --update --vibe --agent claude_code --repo "$workspace" --no-baseline --version "$release_selector"
else
  bash "$tmp" --update --vibe --agent claude_code --repo "$workspace" --no-baseline
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
  exec "$bootstrap_bin" setup --agent claude_code --workspace "$workspace" --installer-url "$installer_url" --release "$release_selector" $bootstrap_install_args "$@"
fi
# The normal path uses reachable-plugin-bootstrap, which install.sh provides.
# No fallback: a missing bootstrap is a failed install, not an opportunity to
# re-run a different command.
echo "REACHABLE: reachable-plugin-bootstrap is not runnable." >&2
echo "  install.sh provides reachable-plugin-bootstrap; its absence means the install did not complete." >&2
exit 1
