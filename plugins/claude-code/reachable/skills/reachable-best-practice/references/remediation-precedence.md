# remediation-precedence

Load when a REACHABLE **remediate directive** is present for a named finding or
scope. This file governs how you act on it under Gate 1 / FAST_TRACK.

Derived from the Claude bootstrap research pack; **rewritten** so it does not
invent `expected_hash` / CAS / foreign-write `unverified` fiction. Identity and
proof belong to remediate admission (S0/S1/V0).

## Precedence

A REACHABLE remediate directive **supersedes** `reachable-best-practice` and
`reachable-path-probe` for the finding and scope it names.

Outside that named scope, the rest of best-practice still applies.

Full stack (highest wins for its scope):

1. Explicit user request
2. Remedi ate directive (this file) for named finding/scope
3. Synthesizer `reachable-security` under `.reachable/ai-rules/`
4. `reachable-best-practice` / `reachable-path-probe`

## What the directive looks like

Follow whatever REACHABLE actually emitted for the attempt (finding id, scope
paths, patch guidance, admission/handoff text). Do **not** require or invent:

```yaml
# NOT part of V1 Gate 1 — do not invent this model
expected_hash: sha256:…
```

If the remediate handoff says the tree moved, the snapshot is stale, or
admission failed, **stop and report** — do not apply a blind fix to a different
state.

## What to do

1. Read the directive / remediate handoff fully before editing.
2. Stay inside the named scope. Files not listed are not part of this remediate.
3. Make the narrowest change that satisfies the directive.
4. Preserve surrounding behavior: public interface, error semantics, other controls.
5. Run the repository's own checks (test / typecheck / lint as configured).
6. Report what you changed **factually** — no security-outcome claims.

## What not to do

- **Do not broaden** the change. Other issues you notice: one sentence, do not fix.
- **Do not argue** with the directive on generic “this pattern is usually fine”
  grounds. Report a *specific* conflict with documented behavior instead of
  substituting your own fix.
- **Do not weaken** tests, types, or other security controls to land the fix.
- **Do not declare the finding fixed / REACHABLE-cleared / no longer exploitable.**
  Only REACHABLE rescan and proof establish closure.

Acceptable: "Added an `org_id` filter to the query in `get_invoice` and updated
the two call sites."

Not acceptable: "Fixed the IDOR", "This resolves F-143", "Verified secure".

## Fixed vs already safe (agent view)

- If the handoff / code shows the flow is already absent, say so as an
  observation and **do not** make a cosmetic edit.
- If you cannot apply the directive without breaking a documented interface,
  stop and report that conflict.
- Concurrent writes and admission outcomes (`unverified`, withhold, etc.) are
  owned by remediate control plane — do not redefine them here.

## Concurrency

While a remediate for a finding is in flight, do not start unrelated work that
writes the same scoped files unless the user explicitly redirects you. If the
user asks for something else that touches those files, say whether you finish
or abandon the remediate first.
