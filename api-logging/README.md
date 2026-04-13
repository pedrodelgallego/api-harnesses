# api-logging

Without a shared logging contract, every service invents its own format. Pipelines break, PII leaks, and incidents take longer to diagnose. This harness fixes the decisions once — fields, correlation, masking, output — and applies them everywhere.

## Who should use it

Any team building a production API whose logs need to be parseable by a collector, searchable across services, and safe to ship to a SIEM. Language and framework agnostic; compose with a language-specific blueprint or reference directly.

## How to use it

Add as a dependency in your blueprint spec or reference directly in a feature spec. The violations table — 8 ERROR, 2 SHOULD NOT — maps to code review criteria and CI policy checks.

## What it contains

- **Structured format** — structured logging library only; JSON in production; human-readable in development; logging disabled in tests
- **Required fields** — every entry carries `timestamp` (ISO-8601 UTC), `level` (string, never number), `msg`, `service`, `correlationId`
- **Correlation** — generate at request edge, propagate via `X-Correlation-ID`, bind to child logger so all entries carry it automatically, echo on every response
- **Log levels** — driven by `LOG_LEVEL` env var; `info` default in production; `trace` never in production
- **Sensitive data** — full redaction for passwords/tokens/secrets; partial mask for cards/SSNs/phones; presence-flag for auth headers; masking at serializer level, never per-call-site
- **Error entries** — full error object as first argument, never `.message` string; structured stack trace array; `build_info` on every error entry
- **Output** — stdout only; log shippers handle routing; never write directly to files or external services
- **Security events** — authentication, authorization failures, rate limit hits, and validation rejections logged at `info` or `warn`
