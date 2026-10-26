# javascript-typescript-security

Load when writing JavaScript, TypeScript, or Node.

## Process execution

```js
// risky — exec runs a shell
exec(`git clone ${repoUrl}`);

// preferred — no shell, arguments passed separately
execFile("git", ["clone", repoUrl], { timeout: 30_000 });
// or spawn("git", ["clone", repoUrl], { shell: false })
```

`spawn` with `shell: true` reintroduces the problem. Never build a command string from input.

## SQL and NoSQL

```js
// risky
db.query(`SELECT * FROM users WHERE email = '${email}'`);

// preferred
db.query("SELECT * FROM users WHERE email = $1", [email]);
```

ORMs bind by default; raw escape hatches (`sequelize.query`, `knex.raw`, `$queryRawUnsafe`) do not.
Prisma: `$queryRaw` with a tagged template binds, `$queryRawUnsafe` does not.

MongoDB: a request body parsed as an object can supply operators where you expected a scalar, so
`{ email: req.body.email }` can become `{ email: { $ne: null } }`. Coerce and validate types before
they reach the query — `String(req.body.email)` or a zod schema.

## Filesystem

```js
// risky
fs.readFile(path.join(BASE, req.params.name));

// preferred
const base = path.resolve(BASE);
const target = path.resolve(base, req.params.name);
if (target !== base && !target.startsWith(base + path.sep)) {
  return res.status(403).end();
}
```

`path.join` does not prevent traversal; `path.resolve` plus the prefix check does. The
`base + path.sep` form matters — a bare `startsWith(base)` also matches `/data-other`.

## HTML and DOM

```js
// risky
el.innerHTML = userComment;
// React
<div dangerouslySetInnerHTML={{ __html: userComment }} />

// preferred
el.textContent = userComment;
// if HTML is genuinely required, sanitize with DOMPurify first
```

React, Vue, Angular, and Svelte escape interpolated values by default. The risk is the escape
hatches (`dangerouslySetInnerHTML`, `v-html`, `bypassSecurityTrust*`, `{@html}`) and URL attributes
— `href={userValue}` accepts `javascript:`, so validate the scheme.

## Dynamic execution

`eval`, `new Function`, `setTimeout("string")`, and `vm.runInNewContext` on input-derived strings are
sinks. `vm` is not a security sandbox. Use a dispatch object keyed by permitted operation names.

## Prototype pollution

Recursive merges and `JSON.parse` output written into objects can set `__proto__`, `constructor`, or
`prototype` and affect every object in the process.

```js
// preferred — reject dangerous keys in any recursive merge over untrusted input
const BLOCKED = new Set(["__proto__", "constructor", "prototype"]);
if (BLOCKED.has(key)) continue;
// or use Object.create(null) / Map for input-keyed collections
```

Same class of problem: unbounded `key` from input used as an object index.

## Express and API handlers

- Put the auth middleware on the router, not on individual routes you have to remember.
- Object-level check inside each handler: `findOne({ _id: id, ownerId: req.user.id })`.
- Validate bodies with a schema (zod, joi, valibot) rather than reading fields ad hoc.
- Mass assignment: never pass `req.body` straight into a model create or update. Pick fields
  explicitly, or the client can set `role`, `isAdmin`, or `balance`.
- `express.json({ limit: "100kb" })` — an unbounded body limit is a trivial DoS.
- CORS: `origin: true` reflects any origin. With `credentials: true` that is effectively public.
  Name the origins.

## Outbound requests

Set an explicit timeout (`AbortSignal.timeout(10_000)` with `fetch`). Decide on redirects
deliberately (`redirect: "manual"` when the destination is input-influenced). Never set
`NODE_TLS_REJECT_UNAUTHORIZED = "0"`.

## Secrets and client bundles

Anything reaching the browser bundle is public. In Next.js, `NEXT_PUBLIC_*` is shipped to the
client; in Vite, `VITE_*`. Server-only secrets must not carry those prefixes and must not be
imported into client components. Keep tokens out of `localStorage` when an httpOnly cookie is
available.

## Cryptography and randomness

```js
// risky
const token = Math.random().toString(36).slice(2);

// preferred
const token = crypto.randomBytes(32).toString("base64url");
```

`crypto.timingSafeEqual` for comparing tokens and MACs (both buffers, same length). Password
storage: argon2 or bcrypt.

## Dependencies

Do not invent package names — hallucinated names are a supply-chain risk in themselves. Prefer a
dependency already in `package.json`. Node's standard library covers most small utilities. When you
do add something, update the lockfile normally.

## Validation

Run the project's existing `npm test`, `tsc --noEmit`, and `eslint`. Do not add new security plugins
to the project's lint config as part of a coding task.
