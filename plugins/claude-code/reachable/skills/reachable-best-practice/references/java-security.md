# java-security

Load when writing Java, Kotlin, or other JVM code.

## Process execution

```java
// risky — shell parses the string
Runtime.getRuntime().exec("sh -c \"convert " + name + " out.png\"");

// preferred
new ProcessBuilder("convert", name, "out.png").start();
```

`ProcessBuilder` with separate arguments does not involve a shell. Do not pass a single
space-joined string.

## SQL

```java
// risky
stmt.executeQuery("SELECT * FROM users WHERE email = '" + email + "'");

// preferred
PreparedStatement ps = conn.prepareStatement(
    "SELECT * FROM users WHERE email = ?");
ps.setString(1, email);
```

JPA/Hibernate: `createQuery("... where email = :e").setParameter("e", email)` binds; string
concatenation into JPQL or `createNativeQuery` does not. Spring Data `@Query` binds `:named` and
`?1` parameters. `JdbcTemplate` binds when values are passed as varargs, not when concatenated into
the SQL string.

Identifiers (table, column, sort direction) cannot be bound — map dynamic values through an enum or
a permitted-value set. `ORDER BY ${userField}` is the most common instance of this.

## Filesystem

```java
// risky
new File(baseDir, userName);

// preferred
Path base = Paths.get(baseDir).toRealPath();
Path target = base.resolve(userName).normalize();
if (!target.startsWith(base)) {
    throw new SecurityException("path escapes base");
}
```

`normalize()` resolves `..` lexically; `Path.startsWith` compares path elements, so it is safe here
(unlike `String.startsWith`). Use `toRealPath()` on the base to resolve symlinks. Zip and tar
extraction must validate every entry's resolved path before writing.

## Deserialization

Java native deserialization reconstructs arbitrary object graphs and is the source of an entire
vulnerability class. Never call `ObjectInputStream.readObject` on data that crossed a trust
boundary. Use JSON or another data-only format with an explicit target type.

Jackson: leave default typing off. `enableDefaultTyping()` and unconstrained
`@JsonTypeInfo(use = Id.CLASS)` let the payload name the class to instantiate. Prefer
`@JsonSubTypes` with a fixed list of permitted subtypes.

## XML

Untrusted XML needs entity and DTD resolution disabled, or an XXE read of local files and internal
URLs becomes possible.

```java
DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
f.setXIncludeAware(false);
f.setExpandEntityReferences(false);
```

The same applies to `SAXParserFactory`, `XMLInputFactory` (`SUPPORT_DTD` false),
`TransformerFactory`, and `SchemaFactory`.

## Spring

- Method-level authorization on the specific object:
  `@PreAuthorize("@authz.canRead(authentication, #id)")`. A class-level `@Secured("ROLE_USER")`
  authenticates but does not authorize the object.
- New endpoints inherit whatever the `SecurityFilterChain` says. If the chain has a permissive
  fallback, a new path may be unauthenticated — check the chain when adding a controller.
- Mass assignment: bind requests to a DTO, not to the JPA entity. Binding directly lets the client
  set fields such as `role` or `enabled`.
- Return DTOs rather than entities, or lazy relations and internal fields leak through serialization.
- `@CrossOrigin("*")` combined with credentials is effectively public.
- SpEL, OGNL, and expression evaluation over input-derived strings is remote code execution; do not
  build expressions from input.

## Outbound requests

Set connect and read timeouts explicitly on `HttpClient`, `RestTemplate`, or `WebClient` — several
default to none. Control redirect following when the destination is input-influenced. Never install
a trust-all `X509TrustManager` or a hostname verifier that returns true.

## Cryptography and randomness

```java
// risky
new Random().nextLong();
MessageDigest.getInstance("MD5");
Cipher.getInstance("AES/ECB/PKCS5Padding");

// preferred
new SecureRandom().nextBytes(buf);
Cipher.getInstance("AES/GCM/NoPadding");        // with a unique 12-byte IV per message
```

`MessageDigest.isEqual` for comparing MACs and tokens. Passwords: `BCryptPasswordEncoder`,
`Argon2PasswordEncoder`, or `SCryptPasswordEncoder`.

## Logging

Do not log credentials, tokens, or full request bodies. Strip newlines from input-derived values
before logging so log lines cannot be forged. Never pass input-derived format strings to a logger
that performs formatting or lookups.

## Validation

Run the project's `mvn test` / `gradle test`, plus its existing static analysis (SpotBugs, Error
Prone, Checkstyle) if configured. Do not add new analysis tooling as part of a coding task.
