#!/usr/bin/env sh
set -eu
package_root="${1:-}"
if [ -z "$package_root" ]; then
  script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  package_root="$(dirname "$script_dir")"
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "reachable: python3 is required to verify the plugin content pin" >&2
  exit 1
fi
python3 - "$package_root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
MANIFEST_NAME = "reachable-skill-manifest.json"
EXCLUDED = {MANIFEST_NAME, "reachable-plugin.json"}
manifest_path = ROOT / MANIFEST_NAME
plugin_path = ROOT / "reachable-plugin.json"
if not manifest_path.is_file():
    raise SystemExit(f"missing content pin: {manifest_path}")
if not plugin_path.is_file():
    raise SystemExit(f"missing {plugin_path}")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
plugin = json.loads(plugin_path.read_text(encoding="utf-8"))
expected_files = manifest.get("files")
expected_hash = manifest.get("content_hash")
if not isinstance(expected_files, dict) or not expected_files:
    raise SystemExit("content manifest files map is empty")
if not isinstance(expected_hash, str) or not expected_hash:
    raise SystemExit("content manifest content_hash is missing")
if plugin.get("content_hash") != expected_hash:
    raise SystemExit("reachable-plugin.json content_hash does not match the content manifest")
actual = {}
for path in sorted(ROOT.rglob("*")):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix()
    if rel in EXCLUDED:
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    actual[rel] = digest
missing = sorted(set(expected_files) - set(actual))
extra = sorted(set(actual) - set(expected_files))
mismatched = sorted(
    rel for rel in set(expected_files) & set(actual) if expected_files[rel] != actual[rel]
)
if missing or extra or mismatched:
    raise SystemExit(
        f"plugin content drifted: missing={missing} extra={extra} mismatched={mismatched}"
    )
lines = [f"{rel}:{digest}" for rel, digest in sorted(actual.items())]
recomputed = hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()
if recomputed != expected_hash:
    raise SystemExit("content_hash mismatch after recompute")
print("reachable: plugin content pin verified")
PY
