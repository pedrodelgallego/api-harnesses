# api-security-headers

HTTP security headers are invisible until they're missing. A wildcard CORS policy on an authenticated endpoint lets any origin make credentialed requests. A missing `Cache-Control: no-store` puts a JWT in a shared cache. Frameworks don't set these by default. This harness makes the correct configuration explicit: 9 ERROR-level rules.

## Who should use it

Any team shipping APIs or web services consumed by browsers, especially services that handle tokens, session data, or PII. Language and framework agnostic; compose with a language-specific blueprint or reference directly.

## How to use it

Add as a dependency in your blueprint spec or reference directly. In most frameworks the 9 rules map to a single middleware registration. Can also drive automated header checks against a running service in CI.

## What it contains

- **Required headers** — HSTS (`max-age=31536000; includeSubDomains`), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'`, `Referrer-Policy`; `Cache-Control: no-store` on any response carrying tokens, credentials, or PII
- **Content Security Policy** — must be present; `unsafe-inline` and `unsafe-eval` prohibited unless a nonce or hash is used
- **Server fingerprinting** — `Server` and `X-Powered-By` stripped explicitly; never rely on the framework omitting them
- **CORS** — origin validated against explicit server-side allowlist; wildcard banned on authenticated endpoints; `Origin` never reflected unconditionally; `X-Correlation-ID`, `Location`, and `Retry-After` in `exposedHeaders`; `Idempotency-Key` in `allowedHeaders` when the API accepts it
