#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
package_root="$(dirname "$script_dir")"
workspace="${REACHABLE_WORKSPACE:-$(pwd)}"
installer_url="${REACHABLE_INSTALLER_URL:-https://sthenosec.com/download/install.sh}"
release_manifest_url="${REACHABLE_RELEASE_MANIFEST_URL:-https://sthenosec.com/download/manifest.json}"
verify_installer="${REACHABLE_VERIFY_INSTALLER:-1}"
verify_plugin_installer="${REACHABLE_VERIFY_PLUGIN_INSTALLER:-1}"
release_selector="${REACHABLE_RELEASE_SELECTOR:-latest}"
local_wheel="${REACHABLE_LOCAL_WHEEL:-}"
bootstrap_install_args="--skip-install"
curl_connect_timeout="${REACH_LLM_CONNECT_TIMEOUT:-5}"
curl_archive_timeout="${REACH_HTTP_ARCHIVE_DOWNLOAD_TIMEOUT:-60}"
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
verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/reachable-install-verify.XXXXXX")"
cleanup() { rm -f "$tmp"; rm -rf "$verify_dir"; }
trap cleanup EXIT
curl -fsSL --connect-timeout "$curl_connect_timeout" --max-time "$curl_archive_timeout" "$installer_url" -o "$tmp"
if [ "$verify_installer" != "0" ]; then
  python_bin="${PYTHON:-}"
  if [ -z "$python_bin" ] && command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
  fi
  if [ -z "$python_bin" ] && command -v python >/dev/null 2>&1; then
    python_bin="$(command -v python)"
  fi
  if [ -z "$python_bin" ]; then
    echo "REACHABLE installer verification requires python; set REACHABLE_VERIFY_INSTALLER=0 only for local artifact proof." >&2
    exit 1
  fi
  if ! command -v cosign >/dev/null 2>&1; then
    echo "REACHABLE installer verification requires cosign; install cosign or set REACHABLE_VERIFY_INSTALLER=0 only for local artifact proof." >&2
    exit 1
  fi
  "$python_bin" - "$tmp" "$installer_url" "$release_manifest_url" "$verify_dir" <<'PY'
import hashlib
import json
from pathlib import Path
import sys
import urllib.request
import urllib.parse

installer_path, installer_url, manifest_url, verify_dir = sys.argv[1], sys.argv[2], sys.argv[3], Path(sys.argv[4])

def timeout_seconds(key, fallback):
    try:
        from reachable.core.config import get_timeout
        return get_timeout(key)
    except Exception:
        return fallback

def load_bytes(url):
    request = urllib.request.Request(url, headers={"User-Agent": "reachable-plugin-installer/1.0"})
    with urllib.request.urlopen(request, timeout=timeout_seconds("http_archive_download_seconds", 60)) as response:
        return response.read()

def load_json(url):
    return json.loads(load_bytes(url).decode("utf-8"))

def write_text(name, value):
    (verify_dir / name).write_text(value, encoding="utf-8")

def write_bytes(name, value):
    (verify_dir / name).write_bytes(value)

def resolve_release_manifest(payload, raw_payload):
    if isinstance(payload.get("install_script_sha256"), str):
        raise SystemExit("legacy installer checksum manifests are not accepted")
    if payload.get("kind") == "reachable_plugin_release_manifest":
        write_bytes("reachable-release-manifest.json", raw_payload)
        return payload, manifest_url
    manifest = payload.get("manifest") or {}
    nested_url = manifest.get("url")
    if not nested_url:
        raise SystemExit("download manifest does not expose reachable-release-manifest.json")
    raw = load_bytes(nested_url)
    write_bytes("reachable-release-manifest.json", raw)
    return json.loads(raw.decode("utf-8")), nested_url

def installer_bundle_url(front_payload, release_manifest_url, installer_record):
    signature = installer_record.get("signature") or {}
    for key in ("url", "asset_url"):
        if isinstance(signature.get(key), str):
            return signature[key]
    if isinstance(signature.get("asset_name"), str):
        return urllib.parse.urljoin(release_manifest_url, signature["asset_name"])
    asset = front_payload.get("install_script_asset") or {}
    if isinstance(asset.get("url"), str):
        return f"{asset['url']}.cosign.bundle"
    if installer_url.startswith(("http://", "https://", "file:")):
        return f"{installer_url}.cosign.bundle"
    if isinstance(installer_record.get("path"), str):
        return urllib.parse.urljoin(release_manifest_url, f"{installer_record['path']}.cosign.bundle")
    raise SystemExit("release manifest does not expose install.sh cosign bundle")

def release_installer_asset_url(front_payload):
    asset = front_payload.get("install_script_asset") or {}
    url = asset.get("url")
    return url if isinstance(url, str) and url else None

front_payload_bytes = load_bytes(manifest_url)
front_payload = json.loads(front_payload_bytes.decode("utf-8"))
release_payload, resolved_release_manifest_url = resolve_release_manifest(front_payload, front_payload_bytes)
write_text("release-manifest-bundle-url", f"{resolved_release_manifest_url}.cosign.bundle")

installer_record = None
for record in release_payload.get("installer_artifacts") or []:
    if record.get("asset_name") == "install.sh" and isinstance(record.get("sha256"), str):
        installer_record = record
        break
if installer_record is None:
    raise SystemExit("release manifest does not include install.sh checksum")

expected = installer_record["sha256"]
write_text("installer-bundle-url", installer_bundle_url(front_payload, resolved_release_manifest_url, installer_record))
actual = hashlib.sha256(open(installer_path, "rb").read()).hexdigest()
if actual != expected:
    release_asset_url = release_installer_asset_url(front_payload)
    if release_asset_url and release_asset_url != installer_url:
        replacement = load_bytes(release_asset_url)
        Path(installer_path).write_bytes(replacement)
        actual = hashlib.sha256(replacement).hexdigest()
    if actual != expected:
        raise SystemExit(f"installer checksum mismatch: expected {expected}, got {actual}")
PY
  curl -fsSL --connect-timeout "$curl_connect_timeout" --max-time "$curl_archive_timeout" "$(cat "$verify_dir/release-manifest-bundle-url")" -o "$verify_dir/reachable-release-manifest.json.cosign.bundle"
  cosign verify-blob     --bundle "$verify_dir/reachable-release-manifest.json.cosign.bundle"     --certificate-oidc-issuer https://token.actions.githubusercontent.com     --certificate-identity-regexp 'https://github.com/sthenos-security/.*'     "$verify_dir/reachable-release-manifest.json" >/dev/null
  curl -fsSL --connect-timeout "$curl_connect_timeout" --max-time "$curl_archive_timeout" "$(cat "$verify_dir/installer-bundle-url")" -o "$verify_dir/install.sh.cosign.bundle"
  cosign verify-blob     --bundle "$verify_dir/install.sh.cosign.bundle"     --certificate-oidc-issuer https://token.actions.githubusercontent.com     --certificate-identity-regexp 'https://github.com/sthenos-security/.*'     "$tmp" >/dev/null
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
  echo "REACHABLE CLI not found after installation" >&2
  exit 1
fi
exec "$reachctl_bin" vibe install --agent claude_code --workspace "$workspace" --no-baseline "$@"
