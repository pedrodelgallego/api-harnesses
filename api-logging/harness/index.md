# API Logging Harness

## Scope
These rules define application logging. Distributed tracing and metrics belong in `api-telemetry.md`.

## Format and Output
- MUST use a structured logger.
- MUST NOT use `console.log` in production.
- MUST emit JSON in production.
- MUST log to stdout only.
- MUST NOT write logs directly to files or external services from application code.
- SHOULD disable or suppress logs in automated tests.

## Required Fields
Every log entry MUST include:
- `timestamp` in RFC 3339 / ISO 8601 UTC form
- `level` as one of `trace`, `debug`, `info`, `warn`, `error`, `fatal`
- `msg` as a specific non-empty message
- `service` as the service name

Request-scoped logs MUST also include:
- `correlationId`
- `traceId` when a trace is active
- `spanId` when a span is active

## Correlation
- MUST create `correlationId` at the request edge when one is not supplied.
- MUST propagate it via `X-Correlation-ID`.
- MUST attach it to every log for the request lifetime.
- MUST echo `X-Correlation-ID` on every response.

## Levels
- MUST configure log level via environment variable.
- Production default MUST be `info`.
- `debug` SHOULD NOT be enabled in production by default.
- `trace` MUST NOT be enabled in production.

## Sensitive Data
- MUST redact at the logger or serializer layer; MUST NOT rely on callers.
- MUST fully redact passwords, secrets, API keys, access tokens, refresh tokens, private keys, CVV, and PINs.
- MUST mask or reduce exposure for card numbers, national identifiers, phone numbers, and email addresses.
- MUST record only presence for `Authorization`, `Cookie`, `Set-Cookie`, and similar credentials.
- MUST NOT log raw sensitive query parameters such as `token` or `api_key`.

## Error Logging
- MUST pass the error object as structured error data.
- MUST NOT log only `err.message`.
- MUST preserve stack traces as structured fields, not flattened strings.
- SHOULD include build or release identity on startup and fatal error logs.

## Security and Audit Signals
- MUST log authentication success and failure.
- MUST log authorization denial.
- MUST log rate-limit breaches.
- MUST log validation rejection at least at `info` or `warn`.
- Security-relevant logs SHOULD include principal, source IP, and `correlationId` when available.
