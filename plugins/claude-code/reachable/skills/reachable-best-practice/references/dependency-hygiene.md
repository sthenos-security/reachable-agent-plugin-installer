# dependency-hygiene

Load when adding, upgrading, or replacing a dependency.

REACHABLE's dependency pipeline is authoritative for whether a package is vulnerable, malicious, or
reachable. This file governs your *coding* behaviour only. Do not attempt to assess a package's
safety yourself, and do not state that a package is safe.

## Prefer not adding one

In order:

1. Something already in the manifest that does the job.
2. The standard library.
3. A new dependency.

A new direct dependency brings its own transitive tree, and generated code has a habit of adding a
package for something the language already does. Left-pad a string, parse a URL, generate a UUID,
deep-clone an object, format a date — check the standard library first.

## Never invent a package name

If you are not certain a package exists under exactly that name, do not add it. Guessed names are a
supply-chain risk in themselves: attackers register plausible-sounding names precisely because
generated code guesses them. This includes:

- guessing at a scoped name (`@acme/logger` when the real one is `acme-logger`);
- guessing at an ecosystem's naming convention for a library you know from another language;
- reconstructing a name from memory of a tutorial.

If you need a capability and cannot confirm the package name, write the code inline or say you need
the name confirmed.

Watch for names that differ from a well-known package by a character, a hyphen, or a scope — those
are typosquats, and they look correct at a glance.

## Choosing the version

Your knowledge of the latest release is months out of date, so an exact version you remember is
probably already vulnerable. Do not present any version you choose as safe.

- **Python and npm (ranges are native).** In a new project do not pin an exact version from memory.
  Give a lower bound you know exists and the next major as the upper bound (`Flask>=3.0,<4`,
  `"express": "^4.19.0"`), so the package manager resolves a current release. The lockfile the package
  manager writes at install holds the exact versions; do not write one by hand.
- **Maven, Gradle, Go (an exact version is required).** Use a version you know exists, keep every
  version in one place (a `<properties>` block, `go.mod`), prefer fewer dependencies (the standard
  library first), and say in your final message that the versions come from memory and must be updated
  and checked before shipping (`mvn versions:display-dependency-updates`, `go list -u -m all`).
- If the project already pins exact versions, follow it (see "Version pinning"). Do not pick a
  pre-release, or a version you are unsure exists; if you do not know a recent version, say so.
- Libraries that most often have advisories (JSON, XML, database drivers, web frameworks, HTTP
  clients, archive and image libraries): fewest of them, and say which versions you chose.
- In your final message, list every dependency you added or changed with the version or range you
  chose, and which of the two cases above applied. You cannot check whether a version is vulnerable
  (REACHABLE does that); the list lets it be checked.

## Version pinning

- Add the dependency the way the project already does it. If the project pins exact versions, pin.
  If it uses ranges, use a range.
- Always update the lockfile in the same change. A manifest change without a lockfile change means
  different versions resolve in CI and in production.
- Do not loosen an existing pin to make resolution succeed. A pin is usually there on purpose.
- Do not add a dependency from a git URL, a tarball URL, or a private registry unless the project
  already does that.

## Install scripts and build hooks

Postinstall scripts, `build.rs`, Gradle init scripts, and `setup.py` execution run with your
privileges at install time. This is not a reason to refuse a package — most are legitimate — but it
is a reason not to add packages casually, and a reason to keep CI installs to `--ignore-scripts`
where the project already does so.

## Upgrades

- Upgrade for a stated reason: a needed feature, a compatibility requirement, or a REACHABLE
  remediation directive.
- Do not bulk-upgrade unrelated dependencies while doing something else. It makes the change
  unreviewable and mixes functional risk into a security change.
- Read the changelog for major version bumps and adapt the calling code rather than adding
  compatibility shims.
- When REACHABLE directs a specific upgrade, take the smallest version that satisfies it.

## Removals

Removing a dependency is fine, but check for remaining imports and for transitive dependents inside
the project before doing it.

## What to report

Nothing, unless something is unresolved. If you added a dependency because you could not confirm an
alternative, or you had to loosen a constraint, or the install triggered something unexpected, put
one line in `unresolved_security_questions`. Do not produce a dependency report — REACHABLE reads
the manifest and lockfile directly.

## What not to claim

Do not say a package is safe, maintained, well-audited, vulnerability-free, or a good choice
security-wise. You cannot know that, and REACHABLE is the component that determines it.
