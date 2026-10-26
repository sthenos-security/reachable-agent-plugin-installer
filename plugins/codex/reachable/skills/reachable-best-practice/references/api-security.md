# api-security

Load when writing HTTP APIs, route handlers, or GraphQL resolvers. The dominant defect in generated
API code is missing object-level authorization, so most of this file is about that.

## Object-level authorization

Every handler that takes an identifier from the client and touches state needs a server-side check
that the caller is entitled to that specific object.

```
// authenticated but not authorized — any user can read any order
GET /orders/:id  →  db.orders.findById(id)

// scoped in the query, so it cannot be dropped by a later refactor
GET /orders/:id  →  db.orders.findOne({ id, customerId: ctx.user.id })
```

Scope in the query rather than fetch-then-compare. The check then lives in one place, and a
subsequent change to the handler can't leave an unscoped object in a variable.

Sequential or guessable identifiers make this worse, but a random UUID is not authorization —
identifiers leak through logs, referrers, exports, and support tickets.

Cover every verb. It is common for `GET` to be scoped and `PATCH` or `DELETE` on the same resource
not to be. Nested routes need the parent checked too: `/projects/:pid/tasks/:tid` must verify that
the caller may access `pid` *and* that `tid` belongs to `pid`.

## Function-level authorization

Administrative and internal endpoints need a role or capability check on the server. Do not rely on
the path being undocumented, on the endpoint being absent from the UI, or on a header the client
supplies. Consider whether a new route lands inside or outside your framework's protected filter
chain — added routes sometimes fall through to a permissive default.

## Input validation

Validate with a schema at the edge (zod, pydantic, JSON Schema, bean validation) rather than reading
fields ad hoc. Reject unknown fields when the shape is fixed. Validate types before values reach a
query, since a client can often send an object or array where a scalar was assumed.

Bound everything that can grow: body size, array lengths, string lengths, page sizes, upload sizes,
and nesting depth.

## Mass assignment

```
// risky — client controls every column
await User.update(req.params.id, req.body);

// preferred — explicit allowed fields
const { displayName, timezone } = req.body;
await User.update(req.params.id, { displayName, timezone });
```

Spreading a request body into a model or entity lets the client set `role`, `isAdmin`, `verified`,
`balance`, or `ownerId`. Pick fields explicitly, or bind to a DTO that only contains editable ones.

## Response shaping

Serialize through an explicit response model rather than returning the database object. Entities
accumulate fields — `passwordHash`, `internalNotes`, `stripeCustomerId`, other users' data through
a lazy relation — and returning them directly leaks whatever gets added later.

Errors: log the detail server-side, return a generic message and a correlation ID. Stack traces,
SQL text, and file paths in responses are free reconnaissance.

## Rate limiting and cost

Rate-limit authentication, password reset, search, export, and anything that triggers outbound calls
or expensive computation. Key on the authenticated principal where possible, not only on IP.

Pagination needs a maximum page size that the client cannot exceed, and a default that is not
"everything".

## GraphQL

- Authorization belongs in resolvers or a field-level rule, not only at the query entry point —
  a nested field can reach an object the top-level check never saw.
- Bound query depth, complexity, and aliases, or a single request can fan out arbitrarily.
- Batch resolvers must apply the same per-object checks as single ones.
- Disable introspection and field suggestions in production if the schema is not public.

## Mutating requests

Use methods with their intended semantics: `GET` should not change state. State-changing browser
requests need CSRF protection (see `web-security.md`); token-in-header APIs generally do not.

Idempotency keys on payment and provisioning endpoints prevent duplicate side effects from retries.

## Webhooks and machine callers

Verify the signature over the raw body before parsing, using constant-time comparison. Check the
timestamp to limit replay. Do not authorize based on source IP alone. Do not accept a `secret` in a
query string — it lands in logs.

## Multi-tenancy

Derive the tenant from the authenticated session, never from a request parameter or header the
client controls. A `X-Org-Id` header taken at face value is a complete tenancy bypass. Apply the
tenant filter in the data layer so individual handlers cannot forget it.
