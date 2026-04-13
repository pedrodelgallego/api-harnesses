# Usage

## Referencing from a blueprint spec

Add the following line under the Routes section of your blueprint spec to pull in these rules:

```markdown
Implements [api-versioning harness](../../api-versioning/harness/index.md).
```

Framework-specific blueprints (Fastify, Go, Rust, Kotlin, Spring Boot) already implement this harness. For custom stacks, reference it directly.

## What to implement

1. **Version from day one** — prefix all routes with `/v1` from the first commit; never retrofit.
2. **URL path versioning only** — use `/v1/`, `/v2/` etc.; never `Accept-Version` headers or `?version=` query params.
3. **One strategy across the portfolio** — pick URL path versioning and apply it everywhere; mixing strategies is an ERROR.
4. **Breaking change = new version** — renaming a field, making an optional field required, restructuring a response, or tightening validation all require a version bump.
5. **Deprecation sequence** — `Announce → Warn in responses → Enforce deadline → Sunset`; always set the sunset date before or at deprecation time; add `Deprecation: true` and `Sunset: <RFC 7231 date>` headers on deprecated-version responses.
6. **Design for longevity** — prefer enums over booleans, optional over required fields; undocumented behaviour is part of the contract.

## Verifying compliance

Check deprecated versions include the required headers:

```bash
curl -sI https://your-api/v1/users | grep -iE "deprecation|sunset"
```

Verify new versions are introduced before removing the old:

```bash
# Both /v1 and /v2 should return 200 during the migration window
curl -s https://your-api/v1/users | jq '.data'
curl -s https://your-api/v2/users | jq '.data'
```
