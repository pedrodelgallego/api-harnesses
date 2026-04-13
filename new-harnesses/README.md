# API Harness Package

This package contains a MECE rewrite of the uploaded harness set.

## Files
- `api-rest-design.md` — general HTTP/JSON API contract
- `api-versioning.md` — compatibility and lifecycle policy
- `api-security.md` — authn/authz, tokens, validation, identifiers, secrets, SSRF, abuse protection
- `api-security-headers.md` — HSTS, CSP, CORS, cache-control, fingerprinting headers
- `api-rest-resilience.md` — timeouts, retries, breakers, health, graceful shutdown, load shedding
- `api-logging.md` — structured application logging and redaction
- `api-telemetry.md` — traces, metrics, propagation, sampling
- `api-testing.md` — testing strategy and coverage expectations
- `fastify-api-blueprint.md` — Fastify-specific implementation blueprint
- `changes.md` — table of changes and rationale

## Design Principles
- `api-*` files are framework-agnostic.
- `fastify-*` files implement the `api-*` rules for Fastify only.
- Cross-file overlap is minimized.
- RFC 9457 is used for problem details.
