# go-security

Load when writing Go.

## Process execution

```go
// risky — a shell parses the whole string
exec.Command("sh", "-c", "tar xf "+name)

// preferred — arguments stay separate
exec.CommandContext(ctx, "tar", "xf", name)
```

`exec.Command` does not use a shell unless you invoke one. Use `CommandContext` so the
process is killed when the request context is cancelled.

## SQL

```go
// risky
db.Query("SELECT * FROM users WHERE email = '" + email + "'")

// preferred
db.QueryContext(ctx, "SELECT * FROM users WHERE email = $1", email)
```

`fmt.Sprintf` into a query string is the same defect. Identifiers cannot be bound — map
dynamic column or table names through an explicit permitted set.

## Filesystem

```go
// risky
os.Open(filepath.Join(base, name))

// preferred — resolve errors fail closed; then contain; then open
target := filepath.Join(base, filepath.Clean("/"+name))
absBase, err := filepath.Abs(base)
if err != nil {
    return err
}
absTarget, err := filepath.Abs(target)
if err != nil {
    return err
}
rel, err := filepath.Rel(absBase, absTarget)
if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
    return errors.New("path escapes base")
}
f, err := os.Open(absTarget)
if err != nil {
    return err
}
```

`filepath.Join` calls `Clean`, which resolves `..` lexically but can still leave `base`.
The `Rel` check enforces containment. `Clean` does not resolve symlinks — use
`filepath.EvalSymlinks` when links matter, and fail closed on error. On Go 1.24+,
`os.Root` gives containment directly where available.

**Never discard errors from `Abs`, `EvalSymlinks`, or open with `_` on a security path.**

## HTML output

```go
// risky
fmt.Fprintf(w, "<div>%s</div>", comment)
template.HTML(userInput)          // asserts "this is safe HTML"

// preferred
tmpl := template.Must(template.New("c").Parse(`<div>{{.}}</div>`))  // html/template
tmpl.Execute(w, comment)
```

`html/template` escapes context-aware; `text/template` does not. Never construct
`template.HTML` / `JS` / `URL` from input.

## HTTP handlers

- Authorization inside the handler, scoped to the object (tenant/owner in the query).
- `http.MaxBytesReader` on bodies; `DisallowUnknownFields` when the shape is fixed.
- Set server timeouts — zero means no timeout.
- Generic client errors; no internal error text to clients.
- `http.ServeFile` with a request-derived path needs the containment check above.

## Outbound requests and SSRF

Never use `http.DefaultClient` for input-influenced URLs — no timeout. Explicit
`Timeout` and `CheckRedirect`. Validate scheme/host per product policy. Block
internal addresses in the dialer after resolution when required. Never
`InsecureSkipVerify: true`.

## Errors must fail closed

```go
// risky — error becomes allow
allowed, err := authz.Check(ctx, user, res)
if err != nil {
    allowed = true
}

// preferred
allowed, err := authz.Check(ctx, user, res)
if err != nil {
    return err
}
```

## Cryptography and randomness

`crypto/rand`, never `math/rand`, for tokens/IDs/nonces/salts.
`subtle.ConstantTimeCompare` for secrets. bcrypt/argon2 for passwords. Prefer AEAD.

## Concurrency

A data race on authz, tokens, or cached identity is a security bug. `go test -race`.

## Validation

`go build ./...`, `go vet ./...`, `go test -race ./...`, plus the project's
`golangci-lint` if present. Do not add new linters as part of a coding task.
