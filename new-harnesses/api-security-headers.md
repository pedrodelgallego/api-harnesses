# API Security Headers Harness

## Scope
These rules define transport and browser-facing response header policy.

## Required Headers
Every eligible response MUST include:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- clickjacking protection via `Content-Security-Policy: frame-ancestors 'none'` or `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin` or stricter

## Content Security Policy
- CSP MUST be present for any response renderable by a browser.
- CSP MUST NOT use `unsafe-inline` or `unsafe-eval` unless a nonce or hash policy explicitly requires it.
- APIs returning only JSON MAY use a minimal CSP, but MUST still define clickjacking protection if browser access is possible.

## CORS
- MUST validate `Origin` against an explicit server-side allowlist.
- MUST NOT use `Access-Control-Allow-Origin: *` on authenticated endpoints.
- MUST NOT reflect `Origin` unconditionally.
- Non-allowlisted origins MUST receive no CORS headers.
- MUST expose cross-origin response headers that clients need, including `X-Correlation-ID`, `Location`, and `Retry-After`.
- APIs that accept idempotency keys MUST allow `Idempotency-Key` in `Access-Control-Allow-Headers`.

## Cache-Control
- Responses containing tokens, credentials, or PII MUST include `Cache-Control: no-store`.
- Sensitive browser flows SHOULD also include `Pragma: no-cache` for older intermediaries when needed.

## Server Fingerprinting
- MUST remove `Server` and `X-Powered-By` explicitly.
- MUST NOT rely on framework defaults for header stripping.
