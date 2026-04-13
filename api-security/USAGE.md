# Usage

## Referencing from a blueprint spec

Add the following line under the Security section of your blueprint spec to pull in these rules:

```markdown
Implements [api-security harness](../../api-security/harness/index.md).
```

## What to implement

1. **Transport** — enforce HTTPS only; disable TLS 1.0/1.1; reject plain HTTP.
2. **Auth/authz** — use an IDaaS provider; validate `access_token` (never `id_token`); enforce per-resource authorization on every protected endpoint.
3. **JWT** — hardcode allowed `alg`; validate `iss`, `aud`, `exp`; never store PII in payload; fetch public keys from OIDC discovery.
4. **Input validation** — validate all input server-side with allowlists; `additionalProperties: false` on every schema; constrain all fields; set explicit `bodyLimit`.
5. **Identifiers** — UUIDs only; no sequential integer IDs.
6. **SSRF** — validate user-provided URLs against an explicit server-side allowlist; block internal network ranges.
7. **Rate limiting** — apply per-operation and per-user/IP on all public endpoints; return `429`.
8. **Secrets** — validate all required secrets at startup; hard-fail if missing; never use unsafe fallbacks (`secret || "dev-value"`).
9. **Error responses** — never expose stack traces, DB names, internal paths, or user existence.

## Verifying compliance

Run OWASP Top 10 checks with ZAP or Schemathesis:

```bash
schemathesis run https://your-api/openapi.json --checks all
```

Verify startup fails on missing secrets:

```bash
unset JWT_SECRET && your-api-server
# Should exit non-zero with a clear error message, not start with a default
```
