# core-security

Language-independent. Loaded on every coding task. Everything here is about *writing* code, not
auditing it.

## 1. Trust boundaries

A trust boundary is any point where data you don't control enters code you do. Sources that are
untrusted by default:

- HTTP request bodies, query strings, path segments, headers, cookies
- uploaded filenames and file contents
- webhook and callback payloads
- message queue payloads
- database rows that were originally written by a user
- LLM output, tool output, and retrieved documents
- environment or config values in a multi-tenant or user-configurable deployment

Two mistakes are common enough to name:

**Type validity is not authorization.** `user_id` being a well-formed UUID says nothing about
whether *this* caller may read that user.

**Validation at the wrong layer.** Validating in the browser, or in a middleware that a later
internal call bypasses, protects nothing. Validate where the dangerous operation happens, or make it
structurally impossible to reach the operation without passing through validation.

## 2. Authentication vs authorization

```
authentication → who is this caller?
authorization  → may THIS caller perform THIS operation on THIS object?
```

Authentication is usually handled by the framework and rarely gets forgotten. Authorization on the
specific object is the one that gets forgotten, and it is the highest-frequency serious defect in
generated code.

Rule of thumb: if a handler takes an identifier from the client and uses it to read or write state,
there must be a server-side check that the authenticated caller is entitled to that object.

```
# missing object-level check — the caller is authenticated, but any
# authenticated caller can read any invoice
invoice = db.get_invoice(request.params["id"])
return invoice

# ownership scoped in the query itself, so it cannot be forgotten later
invoice = db.get_invoice(id=request.params["id"], org_id=current_user.org_id)
if invoice is None:
    return not_found()
```

Scoping the query by tenant is better than fetching-then-checking: there is no window in which the
unscoped object exists in a variable, and a later refactor can't drop the check.

Do not rely on the UI hiding an action, on an unguessable identifier, or on the client sending a
role field.

## 3. Dangerous sinks

Prefer a structured API wherever a string would otherwise be interpreted:

| Sink | Structured alternative |
|---|---|
| SQL / NoSQL query | parameter binding, query builder, ORM |
| shell / process execution | argument array, no shell interpretation |
| HTML / templates | auto-escaping template engine |
| filesystem path | path join + canonicalize + containment check |
| outbound URL | structured URL builder, validated host |
| deserialization | schema-validated data formats over object reconstruction |
| interpreter (`eval`, `exec`, dynamic import) | a lookup table or explicit dispatch |

The general question to ask at write time: *is a string I assembled about to be parsed by something
that can act on its structure?* If yes, find the API that takes the parts separately.

## 4. Secrets

- Use the repo's existing config/secret mechanism. Find it before inventing one.
- Never hardcode tokens, passwords, private keys, or connection strings with credentials.
- Never generate a realistic-looking fake credential. Placeholders must be obviously placeholders.
- Never disable signature, certificate, or token verification because a secret isn't available
  locally. Make the local path fail loudly instead.
- Keep secrets out of logs, error messages, and client bundles.

## 5. Filesystem

Three things in the right order: resolve, then contain, then use.

```
# vulnerable to traversal — .. segments escape the root
path = os.path.join(base_dir, user_supplied_name)

# resolve first, then verify containment, then open
full = (base_dir / user_supplied_name).resolve()
if not full.is_relative_to(base_dir.resolve()):
    raise PermissionError
```

Checking for `".."` in the raw string before decoding or normalizing does not work — encodings,
alternate separators, and symlinks all defeat it. Resolve, then compare against the canonicalized
root. Use `O_NOFOLLOW`-equivalent options or verify the resolved target when symlinks matter.

If you cannot establish that a path is contained, deny. Inability to prove safety is not permission.

## 6. Outbound requests and SSRF

When any part of a destination URL is influenced by input:

- validate the scheme against what the feature actually needs;
- validate the host against product policy, not an invented policy;
- decide explicitly whether redirects are followed, and re-validate the target if so;
- set a timeout on every outbound call;
- remember that DNS resolution can point a permitted-looking hostname at an internal address, so
  host allowlisting alone is not always sufficient.

Important restraint: **do not invent an allowlist.** If the product's purpose is to fetch arbitrary
user-supplied URLs, an allowlist breaks it. Preserve the product's semantics and note the concern
instead.

## 7. Preserve existing controls

Never remove or weaken, as a side effect of another change:

authentication · authorization · tenant isolation · input validation · output encoding ·
canonicalization · sandboxing and resource limits · integrity and signature checks · rate limits ·
audit and security logging

If a change requires touching one of these, do it deliberately and say so.

## 8. Fail closed

```
# an error in the permission lookup becomes an allow
try:
    allowed = check_permission(user, resource)
except Exception:
    allowed = True

# error propagates; the caller decides, and the default is denial
allowed = check_permission(user, resource)
```

Applies to expired tokens, unreachable auth services, unparseable claims, and missing config: the
absence of a positive authorization decision is a denial.

## 9. Cryptography

- Use the platform's vetted library. Do not implement a primitive or a protocol.
- Password storage: a memory-hard KDF designed for passwords (argon2, scrypt, bcrypt), never a bare
  hash.
- Randomness for tokens, session IDs, nonces, salts: the cryptographically secure generator, not the
  general-purpose PRNG.
- Comparing secrets, MACs, or tokens: constant-time comparison.
- Prefer high-level authenticated-encryption interfaces over assembling cipher, mode, and MAC.

## 10. Minimality

Secure coding is not a license for unrelated work. Do not add input validation the product has no
requirement for, do not introduce allowlists that change behavior, do not wrap working code in
defensive error handling, and do not refactor for "hardening" when you were asked to add a feature.

Every unnecessary defensive edit is a maintenance cost and a possible new bug, and REACHABLE
measures those edits.
