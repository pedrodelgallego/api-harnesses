# Usage

## Referencing from a blueprint spec

Add the following line under the Lifecycle & Resilience section of your blueprint spec to pull in these rules:

```markdown
Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md).
```

## What to implement

1. **Timeouts** — set explicit connect and read timeouts on every outbound call; propagate remaining deadline to downstream calls; return `504` on timeout.
2. **Retries** — retry only idempotent operations with exponential backoff + full jitter; honour `Retry-After`; max 3–5 attempts.
3. **Circuit breaker** — apply to every critical external dependency; implement closed/open/half-open states; emit state-change metrics.
4. **Health probes** — `GET /healthz` (no I/O, < 10 ms) and `GET /readyz` (checks all critical deps with timeouts, returns per-dep JSON body).
5. **Graceful shutdown** — handle `SIGTERM`/`SIGINT`; drain in-flight requests; enforce `DRAIN_TIMEOUT_MS`; close DB/broker connections last.
6. **Load shedding** — return `429 + Retry-After` when at capacity; shed at 80%, not 100%.
7. **Bulkheads** — isolate connection pools per dependency; return `503` immediately on exhaustion.

## Verifying compliance

Probe health endpoints directly:

```bash
curl -s https://your-api/healthz | jq .
curl -s https://your-api/readyz | jq '.status, .checks'
```

Verify graceful shutdown by sending `SIGTERM` to the process and checking that in-flight requests complete:

```bash
kill -TERM <pid> && wait <pid>; echo "exit code: $?"
```
