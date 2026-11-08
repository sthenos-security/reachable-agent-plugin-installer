#!/usr/bin/env bash
# Claude Code Stop, non-blocking (FAST-PATH-SKILLS-ENHANCEMENT §14.3 F6).
# At the end of a turn in which the agent wrote code, shows the user ONE line: whether the skill was
# invoked and which reference files were read, plus a warning when a dependency manifest changed and
# dependency-hygiene.md was not requested (the PreToolUse hook sees the request, not whether the host allowed the read). It reads only the records of record-skill-use.sh, says it only
# when it differs from the last line shown for this session, and never blocks (rule 64: an
# observation, no transition reads it). Output is the host's `systemMessage` field.
set -uo pipefail

REACHABLE_HOME_DIR="${REACHABLE_HOME:-$HOME/.reachable}"
LOG_DIR="${REACHABLE_STATE_DIR:-$REACHABLE_HOME_DIR}"
command -v python3 >/dev/null 2>&1 || exit 0
[ -r "$LOG_DIR/adherence.jsonl" ] || exit 0

REACHABLE_HOOK_INPUT="$(cat 2>/dev/null || true)" \
REACHABLE_HOOK_ADHERENCE="$LOG_DIR/adherence.jsonl" python3 - <<'PY' 2>/dev/null || true
import json, os, time

path = os.environ["REACHABLE_HOOK_ADHERENCE"]
try:
    p = json.loads(os.environ.get("REACHABLE_HOOK_INPUT") or "{}")
except ValueError:
    raise SystemExit(0)
session = str((p if isinstance(p, dict) else {}).get("session_id") or "")
if not session:
    raise SystemExit(0)
with open(path, "rb") as fh:
    fh.seek(0, 2)
    fh.seek(max(0, fh.tell() - 262144))
    lines = fh.read().decode("utf-8", "replace").splitlines()
events = []
for line in lines:
    try:
        r = json.loads(line)
    except ValueError:
        continue
    if isinstance(r, dict) and r.get("session") == session:
        events.append(r)
if not any(r.get("event") == "code_written" for r in events):
    raise SystemExit(0)
invoked = any(r.get("event") == "skill_invoked" for r in events)
read = sorted({str(r.get("file")) for r in events if r.get("event") == "reference_read" and r.get("file")})
manifests = sorted({str(r.get("file")) for r in events if r.get("event") == "manifest_written" and r.get("file")})
line = "REACHABLE skills this turn: invoked %s; asked to read: %s" % ("yes" if invoked else "NO", ", ".join(read) or "none")
if manifests and "dependency-hygiene.md" not in read:
    line += ". WARNING: %s changed and dependency-hygiene.md was not requested" % ", ".join(manifests)
last = next((r.get("text") for r in reversed(events) if r.get("event") == "turn_notice"), None)
if last == line:
    raise SystemExit(0)
with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"event": "turn_notice", "text": line, "host": "claude-code", "session": session,
                         "cwd": str(p.get("cwd") or os.getcwd()),
                         "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}, separators=(",", ":")) + "\n")
print(json.dumps({"systemMessage": line}))
PY
exit 0
