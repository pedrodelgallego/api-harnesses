# API Resilience Harness

## Scope
These rules define timeouts, retries, health probes, graceful shutdown, overload control, and degraded behavior.

## Timeouts and Deadlines
- MUST set explicit timeouts on every outbound call.
- MUST separate connect timeout and read timeout.
- MUST propagate the remaining request deadline downstream when supported.
- MUST return 504 on upstream timeout; MUST NOT convert it to an unhandled 500.

## Retries
- MUST retry only idempotent operations: GET, PUT, DELETE, and POST protected by verified idempotency.
- MUST NOT retry mutating calls without idempotency protection.
- MUST retry only transient failures such as connect timeout, 429, 502, 503, and 504.
- MUST NOT retry 400, 401, 403, 404, 409, or 412.
- MUST use exponential backoff with jitter.
- MUST honor `Retry-After`.
- MUST stop immediately on non-retryable outcomes.

## Circuit Breaking and Bulkheads
- MUST use a circuit breaker for every critical external dependency.
- MUST implement `closed`, `open`, and `halfOpen`.
- MUST fail fast while open.
- MUST emit a metric on every state transition.
- MUST isolate pools, queues, or concurrency limits per dependency.
- A slow dependency MUST NOT exhaust shared resources.
- MUST return 503 on pool exhaustion; MUST NOT queue forever.

## Health and Readiness
`GET /healthz`
- MUST return 200 when the local process is healthy.
- MUST return 500 only for unrecoverable local process failure.
- MUST NOT check external dependencies.
- MUST be fast and perform no blocking I/O.

`GET /readyz`
- MUST return 200 only when the service can handle production traffic.
- MUST verify all critical dependencies with timeouts.
- MUST return 503 if any critical dependency is unavailable.
- MUST include per-dependency status in the response body.
- MUST be excluded from auth and rate limiting.

## Graceful Shutdown
- MUST handle `SIGTERM` and `SIGINT`.
- MUST stop accepting new requests when shutdown starts.
- MUST drain in-flight requests before exit.
- MUST use an environment-configured hard drain timeout.
- MUST close downstream clients before exit.
- MUST NOT call `process.exit()` before drain completes, except on forced-timeout paths.

## Load Shedding
- MUST reject excess traffic with 429 before saturation or crash.
- MUST enforce a concurrency limit or bounded queue.
- MUST include `Retry-After` on every 429.
- SHOULD shed load before full saturation.

## Degraded Responses
Preferred order:
1. stale cached data with an explicit degradation signal
2. empty collection or partial capability with an explicit degradation signal
3. 503 with `Retry-After`

- MUST NOT return 200 with silently missing data.
