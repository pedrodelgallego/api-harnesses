# api-versioning

APIs without a versioning strategy become a trap. The first time you need to rename a field you discover there's no migration path. Retrofitting `/v1` after the fact requires coordinated migrations across all consumers. Starting with a version prefix and a deprecation lifecycle costs nothing and prevents months of negotiation. This harness makes those decisions non-negotiable: 5 ERROR-level rules.

## Who should use it

Any team publishing APIs consumed by external clients, multiple internal teams, or long-lived integrations that need a migration window for breaking changes. Language and framework agnostic; compose with a language-specific blueprint or reference directly, especially when evaluating whether a proposed change requires a version bump.

## How to use it

Add as a dependency in your blueprint spec or reference directly. Most relevant at design time and during change review. The breaking-change definition and deprecation sequence can be applied as PR review criteria.

## What it contains

- **When to version** — from day one, `/v1` prefix from the first commit; breaking changes that require a bump: renaming a field, making an optional param required, restructuring a response, tightening validation
- **Strategy** — URL path versioning exclusively (`/v1/resource`); no Accept-Version headers or `?version=` params; one strategy enforced across the entire portfolio, mixing is an ERROR
- **Versioning scheme** — semantic versioning or date-based (`YYYY-MM-DD`); one scheme applied consistently
- **Rollout** — gate to a small consumer group first; versions with no active consumers may be retired early; versions with active consumers must not be retired before sunset date
- **Deprecation** — fixed sequence: Announce → Warn in responses → Enforce deadline → Sunset; `Deprecation: true` and `Sunset: <RFC 7231 date>` headers on every deprecated-version response; sunset date set before or at deprecation announcement, never after
- **Design for longevity** — enums over booleans (booleans can't grow without breaking); optional fields preferred over required; undocumented behaviour is part of the contract
