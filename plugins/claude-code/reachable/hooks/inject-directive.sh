#!/usr/bin/env bash
# Claude Code SessionStart (Gate 1 C1, SECURITY-FAST-SLOW-PATH-v4 rules 60, 64).
# Emits bootstrap-directive.txt as session context and records the activation
# so status and doctor can answer "did the agent get told?" (§13).
# Local file read only. No network. No backend dependency. Never blocks.
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DIRECTIVE="$ROOT/context/bootstrap-directive.txt"
# The same home the runtime uses (REACHABLE_HOME before HOME), so the records
# land where `reachctl vibe status` reads them.
REACHABLE_HOME_DIR="${REACHABLE_HOME:-$HOME/.reachable}"
LOG_DIR="${REACHABLE_STATE_DIR:-$REACHABLE_HOME_DIR}"
ADHERENCE="$LOG_DIR/adherence.jsonl"

mkdir -p "$LOG_DIR" 2>/dev/null || true

# Claude passes {"session_id","cwd","hook_event_name","source"} on stdin.
INPUT="$(cat 2>/dev/null || true)"
HAVE_PY=0
command -v python3 >/dev/null 2>&1 && HAVE_PY=1

# One record per line. python3 writes the JSON (a cwd containing a quote must
# not break the file, §19); without python3 the fields are reduced to what
# bash can quote safely.
_record() {  # event [reason]
  if [[ $HAVE_PY == 1 ]]; then
    REACHABLE_GATE1_EVENT="$1" REACHABLE_GATE1_REASON="${2:-}" \
    REACHABLE_GATE1_INPUT="$INPUT" REACHABLE_GATE1_VERSION="${VERSION:-}" \
    REACHABLE_GATE1_ADHERENCE="$ADHERENCE" python3 - <<'PY' 2>/dev/null || true
import json, os, time
try:
    p = json.loads(os.environ["REACHABLE_GATE1_INPUT"] or "{}")
except ValueError:
    p = {}
if not isinstance(p, dict):
    p = {}
rec = {
    "event": os.environ["REACHABLE_GATE1_EVENT"],
    "host": "claude-code",
    "session": str(p.get("session_id") or "unknown"),
    "cwd": str(p.get("cwd") or os.getcwd()),
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
if os.environ.get("REACHABLE_GATE1_VERSION"):
    rec["directive_version"] = os.environ["REACHABLE_GATE1_VERSION"]
    rec["track"] = "FAST_TRACK"
if os.environ.get("REACHABLE_GATE1_REASON"):
    rec["reason"] = os.environ["REACHABLE_GATE1_REASON"]
with open(os.environ["REACHABLE_GATE1_ADHERENCE"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(rec, separators=(",", ":")) + "\n")
PY
  else
    printf '{"event":"%s","host":"claude-code","session":"unknown","cwd":"unknown","ts":"%s"%s}\n' \
      "$1" "$(date -u +%FT%TZ)" "${2:+,\"reason\":\"$2\"}" >> "$ADHERENCE" 2>/dev/null || true
  fi
}

if [[ ! -r "$DIRECTIVE" ]]; then
  _record skills_activation_miss directive_unreadable
  exit 0   # never block the session
fi

# The version the directive itself declares, not a pin that goes stale.
VERSION="$(sed -n '1s/.*directive v\([0-9][0-9.]*\).*/\1/p' "$DIRECTIVE")"
VERSION="${VERSION:-unknown}"

_record skills_activated

# C1 async tool-warm only -- never block SessionStart on caches or scans.
# The runtime lives in $REACHABLE_HOME/venv/bin, which is not on PATH.
reachctl_bin=""
if [[ -n "${REACHABLE_REACHCTL_BIN:-}" && -x "${REACHABLE_REACHCTL_BIN}" ]]; then
  reachctl_bin="$REACHABLE_REACHCTL_BIN"
elif [[ -x "$REACHABLE_HOME_DIR/venv/bin/reachctl" ]]; then
  reachctl_bin="$REACHABLE_HOME_DIR/venv/bin/reachctl"
elif command -v reachctl >/dev/null 2>&1; then
  reachctl_bin="$(command -v reachctl)"
fi
if [[ -n "$reachctl_bin" ]]; then
  CWD="$PWD"
  if [[ $HAVE_PY == 1 && -n "$INPUT" ]]; then
    CWD="$(REACHABLE_GATE1_INPUT="$INPUT" python3 -c 'import json,os
try: p=json.loads(os.environ["REACHABLE_GATE1_INPUT"])
except ValueError: p={}
print((p.get("cwd") if isinstance(p,dict) else None) or os.getcwd())' 2>/dev/null || echo "$PWD")"
  fi
  ("$reachctl_bin" vibe warm --workspace "$CWD" >/dev/null 2>&1 & ) || true
  _record warm_kicked
fi

cat "$DIRECTIVE"
