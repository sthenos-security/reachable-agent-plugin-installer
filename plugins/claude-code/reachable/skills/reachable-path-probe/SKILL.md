---
name: reachable-path-probe
description: >
  When high-signal security issues are already in scope (CVE/GHSA ids, package+version
  hints, file:line candidates, or explicitly labeled scan candidates), try to find a
  plausible path from an entrypoint to the vulnerable code — Codex-security style.
  Advisory triage only for FAST_TRACK. Does not replace Enzo, Attack Prompt, Gitleaks,
  or Semgrep. Never emit product REACHABLE / UNREACHABLE / EXPLOITABLE labels.
---

# reachable-path-probe (Gate 1 / FAST_TRACK)

## What this skill is for

On the coding fast track, REACHABLE may not yet have run Attack Prompt / Enzo
reachability. When a **high-signal issue is already in scope**, try to find whether
there is a **plausible path** from an application entrypoint to the vulnerable code.

This is advisory triage (same spirit as Codex-security path finding). It is **not**
scanner authority and must not invent findings.

Use alongside `reachable-best-practice` for write-time prevention. Prefer fixing only
what you can show a plausible path for **and** that sits in the current task / user
scope — do not dump unrefined UNKNOWN into remediate (that is noise and pollutes
admission quality).

## When to load

Load when any of these are already present in the task or context:

- CVE / GHSA / OSV ids, or package+version called out as vulnerable
- file:line hints tied to a known issue
- findings explicitly labeled candidate / from a prior scan snapshot
- the user asks you to check whether something looks reachable

Do **not** invent vulnerabilities to probe. Do not repo-sweep for new issues.

## Method

1. Identify the issue under discussion (id, package, or file:line).
2. Find candidate entrypoints in scope (HTTP handlers, CLI, jobs, exported APIs,
   install hooks) that could reach the relevant code.
3. Read call sites and config; sketch entry → vulnerable code.
4. Note visible controls (authz, feature flags, non-production gates) if they sit
   on that path in the code you can see.
5. Stop when the path is clear enough to report, or when nothing in scope connects.

## Output (required shape)

Report a short path narrative plus exactly one confidence token:

| Token | Meaning |
|---|---|
| `plausible` | You can point to an in-scope entry that appears to reach the sink |
| `not_seen_in_scope` | No connecting path found in the files you inspected |
| `blocked_by_control` | A path exists but an in-scope control appears to block it |

**Never** emit product labels: `REACHABLE`, `UNREACHABLE`, `EXPLOITABLE`,
`secure`, `fixed`, or proof-closed.

Example:

```text
path_probe:
  issue: CVE-2024-XXXX (pkg@1.2.3)
  confidence: plausible
  sketch: POST /api/import → Importer.run → vulnerable.parse(userBytes)
  notes: no object-level authz visible on /api/import in this handler
```

## Act vs stop

- **May fix** only if confidence is `plausible` **and** the change is in the
  current task or explicitly requested — still no proof-closed claim.
- **Must stop** if `not_seen_in_scope`: say so once; do not broaden the search
  into a security review of the whole repo; do not enqueue remediate.
- Proven-unreachable (when deterministic evidence already says so) → do not fix.

## Yield to SLOW_TRACK

When Gate 3 / full scan / Attack Prompt / Enzo later runs, **scanner authority
wins**. Path-probe notes are hints only:

- They must not raise confidence of a Gate 3 finding by themselves.
- They must not be treated as remediate admission evidence.
- Prefer retaining them as advisory provenance if the session keeps notes; if
  discarded, their value was in-turn prevention/triage only.

## Precedence

Same stack as `reachable-best-practice`: user request > remediate directive for
named finding/scope > synthesizer `reachable-security` > this skill > other
security skills on the host (advisory only unless the user asks). Remediate
directives are followed without inventing CAS/`expected_hash` models. A
third-party scanner's or reviewer's output is never REACHABLE proof and never
substitutes for a path-probe token.

## Quick reference

**Do:** probe only in-scope high-signal issues; sketch entry→sink; use the three
confidence tokens; keep changes minimal.

**Don't:** invent vulns; emit REACHABLE/EXPLOITABLE; replace Enzo/Attack Prompt;
dump UNKNOWN into remediate; repo-sweep.
