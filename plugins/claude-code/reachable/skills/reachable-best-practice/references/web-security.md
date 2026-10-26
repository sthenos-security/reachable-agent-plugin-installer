# web-security

Load when writing browser-facing code: HTML, templates, cookies, sessions, CORS, CSP, uploads.

## Output encoding

Escaping is context-dependent. Use a template engine that escapes per context. Manual
escaping is where this goes wrong.

Never place input-derived data inside a `<script>` block by string assembly. Pass JSON
in a data attribute or a typed `application/json` script tag and parse client-side.

URL attributes accept `javascript:` and `data:` schemes — validate schemes on
`href` / `src` from input even when escaped.

## Cookies and sessions

```
Set-Cookie: session=…; HttpOnly; Secure; SameSite=Lax; Path=/
```

- `HttpOnly` keeps cookies out of scripts; `Secure` keeps them off plaintext connections.
- `SameSite=Lax` is a sensible default. `None` requires `Secure` and needs a reason.
- Scope `Domain` narrowly. Regenerate session id on login and privilege change;
  invalidate server-side on logout.
- Absolute expiry plus idle timeout.

### Dev / local caveats (required)

- **Do not break local HTTP.** `Secure` cookies and HSTS on `localhost` / plain
  `http://` local apps will lock the developer out. Prefer env-gated flags, e.g.
  set `Secure` only when `NODE_ENV=production` / equivalent, or when the request
  is known HTTPS.
- **Do not enable `Strict-Transport-Security` on localhost** or on an app that is
  intentionally served over HTTP in development.
- In production HTTPS deployments, `Secure` + HSTS (with a reasoned max-age) remain
  appropriate — follow the project's existing pattern rather than inventing policy.

## CSRF

State-changing requests need protection when the browser can send credentials
automatically. Use the framework's built-in CSRF mechanism. `SameSite` helps but
is not a complete substitute for cookie sessions. Header-borne API tokens are a
different CSRF profile.

## CORS

```js
// risky — reflects any origin; with credentials this is effectively public
app.use(cors({ origin: true, credentials: true }));

// preferred
app.use(cors({ origin: ["https://app.example.com"], credentials: true }));
```

Do not build allowed origins by substring match (`endsWith("example.com")` also
matches `evil-example.com`). Name the origins.

## CSP

A useful default when inline script is not required:

```
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none';
  base-uri 'self'; frame-ancestors 'self'
```

`'unsafe-inline'` / `'unsafe-eval'` remove most of the value. Prefer nonces if
inline is unavoidable. CSP does not replace output encoding.

Related: `X-Content-Type-Options: nosniff`,
`Referrer-Policy: strict-origin-when-cross-origin`, HSTS **only on HTTPS
non-local origins**, `frame-ancestors` / `X-Frame-Options`.

## Redirects

```
// risky — open redirect
res.redirect(req.query.next);

// preferred — relative paths only, or a permitted host set
const next = req.query.next ?? "/";
if (!next.startsWith("/") || next.startsWith("//")) return res.redirect("/");
res.redirect(next);
```

`//evil.com` is protocol-relative and looks relative.

## File uploads

- Never trust client filename or `Content-Type`. Generate storage names.
- Validate type from content; size limit on the server.
- Store outside the web root or on non-executing storage.
- Serve user content with explicit `Content-Type` and often
  `Content-Disposition: attachment`.

## Authentication flows

- Rate-limit login, reset, token exchange.
- Identical failure responses whether or not the account exists.
- Reset tokens: random, single-use, short-lived, invalidated on use.
- OAuth/OIDC: validate `state` and `nonce`; PKCE for public clients; exact
  `redirect_uri` match.
- Verify JWT signature and expiry server-side; do not trust client-readable claims alone.

## Client-side storage

Prefer httpOnly cookies for session material. Do not put tokens or personal data
in URLs (history, logs, referrers).
