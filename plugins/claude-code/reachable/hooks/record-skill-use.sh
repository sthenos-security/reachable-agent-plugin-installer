#!/usr/bin/env bash
# Claude Code PreToolUse, non-blocking (FAST-PATH-SKILLS-ENHANCEMENT §14.3 F4; PostToolUse is not
# sent for Read in Claude Code 2.1.319, so a read is recorded when the agent asks for it).
# Records, in adherence.jsonl next to `skills_activated`, what the agent did with the
# guidance: `skill_invoked` (the skill name), `reference_read` (the file name of a file read
# under the skill's references/ folder) and `code_written` (once per session, the first
# Write/Edit/MultiEdit), and `manifest_written` (file name of a dependency manifest). Nothing else is recorded: any other Read, any other tool, and every
# path other than the reference file name is dropped (rule 79: no repo-derived text).
# Measurement only (rule 64): no transition reads it. Never blocks, never prints.
set -uo pipefail

REACHABLE_HOME_DIR="${REACHABLE_HOME:-$HOME/.reachable}"
LOG_DIR="${REACHABLE_STATE_DIR:-$REACHABLE_HOME_DIR}"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

REACHABLE_HOOK_INPUT="$(cat 2>/dev/null || true)" \
REACHABLE_HOOK_ADHERENCE="$LOG_DIR/adherence.jsonl" python3 - <<'PY' 2>/dev/null || true
import json, os, re, time

try:
    p = json.loads(os.environ.get("REACHABLE_HOOK_INPUT") or "{}")
except ValueError:
    raise SystemExit(0)
if not isinstance(p, dict):
    raise SystemExit(0)
tool = p.get("tool_name")
inp = p.get("tool_input") if isinstance(p.get("tool_input"), dict) else {}
session = str(p.get("session_id") or "unknown")
path = os.environ["REACHABLE_HOOK_ADHERENCE"]

rec = None
extra = []
if tool == "Skill":
    name = str(inp.get("skill") or "")
    if re.fullmatch(r"[A-Za-z0-9:_.-]{1,80}", name):
        rec = {"event": "skill_invoked", "skill": name}
elif tool == "Read":
    fp = str(inp.get("file_path") or "")
    base = os.path.basename(fp)
    if "/reachable-best-practice/references/" in fp.replace("\\", "/") and re.fullmatch(r"[A-Za-z0-9._-]{1,80}\.md", base):
        rec = {"event": "reference_read", "file": base}
elif tool in ("Write", "Edit", "MultiEdit"):
    seen = False
    try:
        with open(path, "rb") as fh:
            fh.seek(0, 2)
            fh.seek(max(0, fh.tell() - 65536))
            tail = fh.read().decode("utf-8", "replace")
        seen = any(
            '"event":"code_written"' in line and json.dumps(session) in line for line in tail.splitlines()
        )
    except OSError:
        seen = False
    if not seen:
        rec = {"event": "code_written"}
    base = os.path.basename(str(inp.get("file_path") or ""))
    if re.fullmatch(r"pom\.xml|go\.mod|package\.json|requirements[A-Za-z0-9._-]*\.txt", base):
        extra.append({"event": "manifest_written", "file": base})
recs = ([rec] if rec else []) + extra
if not recs:
    raise SystemExit(0)
common = {"host": "claude-code", "session": session, "cwd": str(p.get("cwd") or os.getcwd()),
          "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
with open(path, "a", encoding="utf-8") as fh:
    for r in recs:
        fh.write(json.dumps({**r, **common}, separators=(",", ":")) + "\n")
PY
exit 0
