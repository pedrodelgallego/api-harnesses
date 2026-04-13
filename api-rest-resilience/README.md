# api-rest-resilience

Most production API failures aren't bugs — they're missing timeouts, absent retries, no circuit breakers, and graceful shutdown never implemented. Under load, one slow dependency takes down the whole service. This harness makes the standard resilience patterns non-negotiable: 14 ERROR-level rules.

## Who should use it

Any backend team shipping services that call other services or databases and need to survive traffic spikes and dependency failures. Language and framework agnostic; compose with a language-specific blueprint or reference directly.

## How to use it

Add as a dependency in your blueprint spec or reference directly. The violations table — 14 ERROR, 3 SHOULD NOT — maps directly to code review and CI checks.

## What it contains

- **Timeouts** — explicit connect and read timeouts on every outbound call, never OS defaults; deadline propagated to every downstream call in the same request; 504, never 500, on timeout
- **Retries** — idempotent operations only; exponential backoff with full jitter (100–500 ms base, 2× multiplier, max 3–5 attempts); Retry-After header respected on 429 and 503
- **Circuit breaker** — three-state machine (closed/open/half-open) on every critical dependency; degraded response when open, never waiting for a timeout; state-change metrics emitted
- **Health probes** — `/healthz` liveness: no I/O, no external deps, <10 ms; `/readyz` readiness: real dependency checks with per-dep timeout, JSON body with per-check status
- **Graceful shutdown** — SIGTERM/SIGINT handled; new connections rejected immediately; in-flight requests drained; hard timeout from `DRAIN_TIMEOUT_MS` env var; DB pool closed before exit
- **Load shedding** — 429+Retry-After before OOM; concurrency limit enforced; shed at 80% capacity, not 100%
- **Bulkheads** — per-dependency pool isolation; immediate 503 on exhaustion, never queue indefinitely; exhaustion metric emitted
- **Degraded responses** — stale cache → empty collection with `meta.degraded: true` → 503; never silent 200 with missing data
