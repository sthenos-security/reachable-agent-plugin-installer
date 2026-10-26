---
name: reachable-best-practice
description: >
  Write secure-by-default code and preserve existing security boundaries when creating or
  modifying source code. Use this skill whenever you are writing, editing, scaffolding, or
  refactoring application code — new features, endpoints, handlers, queries, file or process
  operations, auth logic, agent/MCP/RAG code, or new dependencies — even when the user did not
  mention security. This skill is preventive: it shapes code as it is written. It does not scan,
  audit, or verify. REACHABLE's scan and remediate paths are authoritative for findings,
  reachability, exploitability, remediation, and proof. Not the synthesizer skill
  reachable-security.
---

# reachable-best-practice (Gate 1 / FAST_TRACK)

## What this skill is for

You are writing code that may later be analyzed by REACHABLE. Your job is to make that code
correct and secure *as you write it*, so fewer real defects ever exist.

You are not a scanner. You do not audit the repository, sweep for patterns, or report findings.

1. **Prevention beats detection here.** Spend attention at write time.
2. **You cannot establish exploitability.** Do not claim REACHABLE / UNREACHABLE / EXPLOITABLE /
   secure / fixed. Factual descriptions of what you wrote are fine.
3. **Unnecessary defensive code is a real cost.** Restraint is part of the job.

## Step 1 — Establish scope

Before writing, identify files, languages, frameworks, trust boundaries, and whether
dependencies or lockfiles change.

Then load references. **Always load `references/core-security.md`.** Load others only when they
apply. Two or three topical refs is normal. Loading all is a mistake.

| Load this | When you are writing |
|---|---|
| `core-security.md` | always |
| `python-security.md` | Python |
| `javascript-typescript-security.md` | JS, TS, Node |
| `go-security.md` | Go |
| `java-security.md` | Java, Kotlin, JVM |
| `web-security.md` | browser-facing HTML, templates, cookies, CORS, CSP |
| `api-security.md` | HTTP APIs, handlers, routes, GraphQL |
| `dependency-hygiene.md` | adding, upgrading, or replacing a dependency |
| `agent-llm-rag-security.md` | LLM calls, prompts, tool wrappers, MCP servers, retrieval |
| `remediation-precedence.md` | acting on a REACHABLE remediate directive |

There is no Rust reference in V1 that implies remediate support.

For high-signal issues already in scope (CVEs, labeled candidates), also use the sibling skill
`reachable-path-probe` — path finding is advisory only.

## Step 2 — Read before you change

- Follow the project's conventions; reuse existing security helpers.
- Identify what the current code already protects and keep it intact.
- **Never weaken a security control** to make code, a test, a type check, or a build pass.
  If you cannot proceed without removing a control, stop and say so.

## Step 3 — Write it secure by default

- Treat input as untrusted until validated (bodies, params, headers, cookies, filenames,
  env you did not set, user-written DB content, webhooks, model/tool output).
- Use structured APIs instead of building strings for interpreters (SQL bind, argv arrays,
  template auto-escape, path join + containment).
- Put authorization next to the operation it protects (object/tenant scope on the server).
- Keep secrets out of source; use the repo's existing secret mechanism.
- Fail closed when a security check errors or a value is missing.
- Prefer boring established primitives; keep the change minimal.

## Step 4 — Preflight your own diff before handoff

After writing, review only the files you changed in this task (plus directly affected
manifests/lockfiles and their focused tests). The goal is to shave obvious defects off the
scanner's workload — not to scan.

High-confidence checklist — fix now only when the safe replacement is local and obvious:

- hardcoded credential, private key, or token
- command/query/template string built from untrusted input (should be argv/bind/auto-escape)
- path join without containment, traversal-prone
- TLS verification, auth check, or validator disabled or bypassed
- escaping bypassed where the framework auto-escapes (`dangerouslySetInnerHTML`, `|safe`)
- unsafe deserialization or dynamic evaluation of input
- sensitive data flowing to logs, model context, or outbound calls
- new dependency without a lockfile update or with suspicious install behavior

Rules:

- **Never weaken an existing control to pass preflight** — validation, authz, TLS, audit,
  sanitization stay intact.
- **Never auto-rotate or delete a found credential** — remove it from source and flag the
  rotation requirement to the user.
- **Never upgrade past the smallest compatible safe version** without scanner evidence.
- If intent or impact is uncertain → defer, do not guess or broaden the search.
- Run the narrowest existing check for the changed behavior (test/lint/typecheck). Do not
  invent test commands when the project exposes none.
- If a preflight edit breaks the scoped behavior, revert just that edit and mark it deferred.
- **Do not run the scanner yourself.** Your pass finishes inside the current task —
  `reachctl scan` / remediate runs when the user or pipeline invokes it, on its own
  schedule. Shaving defects off its workload is your whole contribution; triggering it
  early (or repeatedly) defeats the point.

Outcomes — use exactly these tokens, never `secure`/`fixed_verified`/`REACHABLE`:

| token | meaning |
|---|---|
| `fixed_locally` | obvious defect corrected + focused check passed |
| `deferred_to_scanner` | uncertain or non-local — leave for REACHABLE |
| `needs_user_input` | requires a decision (e.g. credential rotation) |
| `verification_failed` | fix attempted, check failed, edit reverted |

This preflight is not a scan and cannot establish security or closure. The REACHABLE scan
remains authoritative. Emit a one-line summary only when something was fixed, deferred, or
failed verification — otherwise stay silent.

## Step 5 — Scope limit

- Fix security issues only in code you are writing or editing **as part of the current task**.
- Do not open unrelated files looking for problems. Do not repo-harden.
- If you notice something concerning outside the task, one sentence at the end — do not fix it.

## Step 6 — Authority and precedence

REACHABLE decides security outcomes. You do not claim posture or closure.

Precedence (highest wins for its scope):

1. **Explicit user request** — implement as asked; one-sentence concern; never silent substitute.
2. **REACHABLE remediate directive** for a **named finding or scope** — wins over this skill
   for that finding/scope only. Read `references/remediation-precedence.md`. Follow the
   directive; do not broaden it. Do not invent CAS / `expected_hash` fiction; remediate
   admission (S0/S1/V0) owns identity and proof.
3. **Synthesizer `reachable-security`** under `.reachable/ai-rules/` — wins over this skill
   on conflicts when present.
4. **This skill** — best-practice prevention for everything else.
5. **Other security skills** installed on this host (vendor scanner skills, review-fleet
   security reviewers, generic hardening skills) — advisory only, unless the user explicitly
   asks to use one. Never present a third-party scanner's or reviewer's output as REACHABLE
   proof or as a REACHABLE / UNREACHABLE / EXPLOITABLE verdict.

## Step 7 — Explicit user requests win

If the user asks for something this guidance discourages (`shell=True`, disabled TLS verify,
hardcoded dev token, skipped authz in a harness):

1. Do as asked.
2. One sentence of concern, no lecture.
3. Do not quietly substitute a “safer” version.

## Step 8 — Handoff

Do not emit changed-file inventories, security checklists, or `applied: true` claims.
Do not emit `unresolved_security_questions` YAML unless a REACHABLE consumer for it is
present in the session. Prefer silence over fake telemetry.

## Quick reference

**Do:** parameterize; validate at boundaries; authorize at access; reuse helpers; fail closed;
keep secrets in config; keep changes small; load only relevant refs.

**Don't:** claim secure/fixed/REACHABLE; audit unrelated code; invent credentials or package
names; weaken a control to pass a test; silently override the user; name this skill
`reachable-security`.
