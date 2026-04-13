# Usage

## Referencing from a blueprint spec

Add the following line under the Security section of your blueprint spec to pull in these rules:

```markdown
Implements [api-security-headers harness](../../api-security-headers/harness/index.md).
```

Framework-specific blueprints (Fastify, Go, Rust, Kotlin, Spring Boot) already implement this harness. For custom stacks, reference it directly.

## What to implement

1. Register a security-headers middleware or plugin **before** route definitions.
2. Configure your CORS plugin with an explicit `allowedOrigins` list from environment config — never `"*"`.
3. Strip `Server` and `X-Powered-By` via framework config or an explicit response hook.
4. Add `Cache-Control: no-store` to any endpoint that returns tokens, session data, or PII.
5. Ensure `X-Correlation-ID`, `Location`, and `Retry-After` appear in `exposedHeaders`.
6. Ensure `Idempotency-Key` appears in `allowedHeaders` if your API accepts it.

## Verifying compliance

Run a quick header check against a staging deployment:

```bash
curl -sI https://your-api/v1/healthz | grep -iE "strict-transport|x-content-type|x-frame|content-security|referrer|cache-control"
```

Check CORS headers on a preflight request:

```bash
curl -sI -X OPTIONS https://your-api/v1/users \
  -H "Origin: https://allowed-origin.com" \
  -H "Access-Control-Request-Method: POST"
```
