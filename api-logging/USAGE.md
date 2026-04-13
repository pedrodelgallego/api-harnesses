# Usage

## Referencing from a blueprint spec

Add the following line under the Logging section of your blueprint spec to pull in these rules:

```markdown
Implements [api-logging harness](../../api-logging/harness/index.md).
```

Framework-specific blueprints (Fastify, Go, Rust, Kotlin, Spring Boot) already implement this harness. For custom stacks, reference it directly.

## What to implement

1. **Structured logger** — use a structured logging library (Pino, slog, tracing, SLF4J); never `console.log` or `print` in production.
2. **Required fields** — every entry must carry `timestamp` (ISO-8601 UTC), `level` (string), `msg`, `service`, and `correlationId`.
3. **JSON in production** — enable JSON format in production; human-readable only in development; discard output in tests.
4. **Correlation ID** — generate at request edge if absent; propagate downstream via `X-Correlation-ID`; bind to a child/scoped logger; echo on every response.
5. **Sensitive data** — mask at the serializer level: full redact for secrets/tokens/passwords; partial mask for cards/SSNs; presence-flag for auth headers.
6. **Log levels** — read from `LOG_LEVEL` env var; default `info` in production; never `trace` in production.
7. **Errors** — pass the full error object (not `.message`); include structured stack trace; include `build_info` on error entries.
8. **Output** — stdout only; use a log shipper (Vector, Fluentd) for routing.

## Verifying compliance

Confirm a request produces a JSON log entry with all required fields:

```bash
curl -s https://your-api/v1/users
# Check stdout for: {"timestamp":"...","level":"INFO","msg":"...","service":"...","correlationId":"..."}
```

Confirm `X-Correlation-ID` is echoed on the response:

```bash
curl -sI https://your-api/v1/healthz | grep -i x-correlation-id
```
