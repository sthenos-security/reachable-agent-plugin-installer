# python-security

Load when writing Python. Pairs are `# risky` / `# preferred`.

## Process execution

`shell=True` makes the whole string a shell command, so any interpolated value can add commands.

```python
# risky
subprocess.run(f"convert {infile} {outfile}", shell=True)

# preferred — argument array, no shell involved
subprocess.run(["convert", infile, outfile], check=True, timeout=30)
```

If a shell feature is genuinely required (pipes, globbing), pass a fixed command string with no
interpolation, or use `shlex.quote()` on every interpolated value — argument arrays first, quoting
only as a fallback. `os.system` takes a shell string by construction; prefer `subprocess`.

## SQL

```python
# risky
cur.execute(f"SELECT * FROM users WHERE email = '{email}'")

# preferred
cur.execute("SELECT * FROM users WHERE email = %s", (email,))
```

ORMs: `filter(User.email == email)` binds; `filter(text(f"email = '{email}'"))` and
`.raw()`/`.extra()` with f-strings do not. Table and column names cannot be bound as parameters —
if they must be dynamic, map input through an explicit dict of permitted names rather than
interpolating.

## Filesystem

```python
# risky
open(os.path.join(UPLOAD_DIR, filename))

# preferred
base = Path(UPLOAD_DIR).resolve()
target = (base / filename).resolve()
if not target.is_relative_to(base):
    raise PermissionError("path escapes upload directory")
open(target, "rb")
```

`is_relative_to` is 3.9+. Below that, compare `os.path.commonpath([base, target]) == str(base)`.
Archive extraction is a frequent traversal source — validate each member's resolved path before
writing, or use `tarfile.extractall(filter="data")` on 3.12+.

## Deserialization

`pickle`, `marshal`, and `shelve` reconstruct arbitrary objects and can execute code during load.
They are safe only for data you produced and stored where nothing untrusted can modify it.

```python
# risky
config = yaml.load(untrusted)
state = pickle.loads(request.data)

# preferred
config = yaml.safe_load(untrusted)
state = MyModel.model_validate_json(request.data)   # pydantic, or json + explicit schema
```

XML from untrusted sources: use `defusedxml`, or disable entity resolution and DTD loading.

## Dynamic execution

`eval`, `exec`, and `compile` on anything derived from input are the sink itself. For "run the
operation the user named", use a dict of permitted callables. `getattr(obj, user_string)` is a
narrower version of the same problem — constrain the name against a known set first.

## Web frameworks

- Authorization goes in the view or a dependency the view actually declares, not in a comment.
- Django: `get_object_or_404(Invoice, pk=pk, org=request.user.org)` — scope the query, don't fetch
  then check. Keep `@login_required` / permission classes on new views; DRF views without an
  explicit `permission_classes` inherit defaults that may be permissive.
- FastAPI: put the auth dependency on the route or router, not only in docs. Response models
  prevent accidental field leakage — declare them.
- Flask: `send_file` / `send_from_directory` with user-influenced paths needs the containment check
  above; `send_from_directory` already constrains, `send_file` does not.
- Redirects: validate that a user-supplied `next` parameter is a relative path or a permitted host.
- Debug mode and interactive tracebacks must be off outside development.

## Outbound HTTP

```python
# risky
requests.get(user_url)                      # no timeout, follows redirects anywhere

# preferred
requests.get(url, timeout=(3, 10), allow_redirects=False)
```

Never `verify=False`. If a private CA is needed, pass `verify="/path/to/ca.pem"`.

## Temporary files

`tempfile.NamedTemporaryFile` / `mkdtemp` / `TemporaryDirectory`. Do not build a temp path from a
predictable name and then open it — that is a race. `mktemp` is deprecated for this reason.

## Cryptography and randomness

```python
# risky
token = str(random.randint(100000, 999999))
digest = hashlib.md5(password.encode()).hexdigest()

# preferred
token = secrets.token_urlsafe(32)
# password storage: argon2-cffi, bcrypt, or hashlib.scrypt — never a bare hash
```

Use `hmac.compare_digest` for comparing tokens and MACs. Prefer `cryptography`'s Fernet or AEAD
constructions over assembling cipher and MAC by hand.

## Secrets and config

Read from the mechanism already in the repo (`os.environ`, pydantic settings, a secret manager
client). Do not add a hardcoded default that works — a missing required secret should raise at
startup, not silently fall back.

## Validation

Run what the repo already has: `pytest`, `ruff`/`flake8`, `mypy`, and the project's own lint config.
Do not add `bandit` or a new security linter to the project as part of a coding task.
