# API Security Harness

## Scope
These rules define authentication, authorization, input hardening, identifiers, secrets, and abuse protection. Transport headers belong in `api-security-headers.md`.

## Transport and Exposure
- MUST require HTTPS in production.
- MUST NOT accept plain HTTP except behind trusted local development tooling.
- Internal APIs MUST meet the same security bar as public APIs.

## Authentication and Authorization
- MUST require authentication and per-resource authorization on every protected endpoint.
- Role membership alone MUST NEVER grant access without resource scope, tenant scope, ownership, or policy checks.
- MUST return 401 for missing or invalid credentials.
- MUST return 403 when credentials are valid but insufficient.
- MUST protect against BOLA/IDOR by validating access to the referenced resource, not just the caller role.

## Identity, Tokens, and OAuth
- MUST use an external identity provider.
- MUST use OIDC for user authentication.
- MUST use `access_token` for API authorization.
- MUST NEVER use `id_token` for API authorization.
- MUST scope tokens to least privilege.
- MUST pin accepted JWT algorithms server-side.
- MUST validate `iss`, `aud`, `exp`, and token signature on every token.
- MUST fetch signing keys from the provider discovery or JWKS endpoint.
- MUST use short-lived access tokens.
- MUST NOT place PII in JWT claims; use opaque `sub`.
- MUST use authorization code + PKCE for user-facing applications.
- MUST use client credentials for machine-to-machine access.
- MUST NOT use implicit flow or resource owner password credentials flow.

## Input and Output Validation
- MUST validate all server-side input for type, format, length, range, and allowed values.
- MUST use allowlists.
- MUST NOT rely on blocklists as the primary control.
- MUST reject unknown fields unless the API contract explicitly says otherwise.
- MUST constrain arrays, strings, and numbers with explicit limits.
- MUST reject null bytes.
- MUST validate third-party, internal-service, and database-derived data before trust.
- MUST validate response payloads before sending them.

## Database and Injection Safety
- MUST use parameterized queries or a safe query builder.
- MUST NOT concatenate untrusted input into SQL.
- MUST NOT concatenate untrusted input into shell commands, templates, LDAP queries, or other interpreters.

## Identifiers
- MUST use UUIDs or opaque surrogate IDs for externally visible identifiers.
- MUST NOT expose sequential integer IDs for protected resources.

## SSRF and Egress Control
- MUST allow outbound requests only to explicit server-side allowlists when the destination is influenced by user input.
- MUST block loopback, link-local, and private network ranges for user-influenced outbound requests.
- MUST apply SSRF controls to webhooks, redirect URIs, import URLs, and similar flows.

## Secrets
- MUST NOT use fallback secrets in code.
- Missing required secrets MUST fail startup.
- MUST validate secrets at startup with a typed env schema.
- MUST enforce secret minimum lengths in the schema.
- MUST NOT return secrets, credentials, or internal tokens in responses.
- MUST NOT log secrets or PII.

## Abuse Protection
- MUST rate-limit public endpoints.
- MUST apply tighter controls to login, token, reset, and verification endpoints.
- MUST return 429 on rate-limit breach.
- MUST bound list sizes and request body sizes.
- MUST pair API keys with authorization controls; a valid key alone MUST NOT grant broad access.

## Auditability
- MUST emit immutable audit logs for writes to sensitive data and privileged actions.
- Audit logs MUST capture who, what, when, and target resource.
