# api-security

Security is the area most costly when it fails and most likely to be implemented inconsistently. Rolling your own auth, reading the JWT algorithm from the token header, using sequential integer IDs, and checking only role membership are all common and all exploitable. This harness defines the baseline as 22 machine-checkable rules.

## Who should use it

Any team building APIs that authenticate users or services, handle sensitive data, or face the internet. Language and framework agnostic; compose with a language-specific blueprint or reference directly. The violations table also drives threat-model reviews and CI policy checks.

## How to use it

Add as a dependency in your blueprint spec or reference directly. The 22 ERROR-level rules map to Spectral rules, code review criteria, and static analysis gates.

## What it contains

- **Authentication & authorization** — IDaaS provider mandatory, never custom crypto; per-resource authorization on every protected endpoint, role membership alone insufficient; `access_token` not `id_token`; internal APIs held to the same standard as public
- **JWT** — signing algorithm hardcoded in validation, never read from token header; `iss`, `aud`, `exp` validated on every token; short expiry; no PII in payload; public keys from OIDC discovery endpoint
- **OAuth 2.1** — authorization code + PKCE for user-facing flows; client credentials for M2M; implicit and ROPC flows prohibited
- **Input validation** — server-side allowlists; `additionalProperties: false` on every request schema; explicit `bodyLimit` on every endpoint; parameterized queries, never concatenated SQL; null bytes rejected; external data treated as untrusted
- **Identifiers** — UUIDs only; sequential integer IDs prohibited (prevent enumeration and BOLA)
- **SSRF** — user-provided URLs validated against server-side allowlist; localhost and internal network ranges blocked; applies to webhooks, redirect URIs, and any server-initiated HTTP call
- **Rate limiting & brute force** — per-operation and per-user/IP rate limiting; unbounded pagination blocked; 429 on breach
- **Error responses** — generic messages only; stack traces, DB names, table names, and user existence never exposed
- **Logging & observability** — security event logging per api-logging harness; per-user rate metrics; immutable audit trail for all writes on sensitive data
- **Secrets management** — secrets validated at startup with hard failure; `secret || "dev-value"` is an ERROR; minimum length constraints enforced in schema; API keys scoped with authorization controls
