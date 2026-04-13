# Usage

## Referencing from a blueprint spec

Add the following line under the Telemetry section of your blueprint spec to pull in these rules:

```markdown
Implements [api-telemetry harness](../../api-telemetry/harness/index.md).
```

Framework-specific blueprints (Fastify, Go, Rust, Kotlin, Spring Boot) already implement this harness. For custom stacks, reference it directly.

## What to implement

1. **SDK init** — initialize the OTel SDK with required Resource attributes before the app starts; shut it down in the graceful shutdown sequence.
2. **Three signals** — emit traces, metrics, and logs from every service; export all via OTLP to the OTel Collector.
3. **Auto-instrumentation** — use the framework's official OTel integration; register before any route definition.
4. **Span naming** — use route templates (`GET /users/:id`), never resolved URLs (`GET /users/42`).
5. **Span status** — set `ERROR` on 5xx only; never on 4xx.
6. **Trace propagation** — inject W3C `traceparent`/`tracestate` on all outbound calls; extract on all inbound; attach `trace_id` and `span_id` to every log entry.
7. **Metrics** — name with dot-notation + unit suffix; use `Histogram` for latency/size; never use high-cardinality dimensions.
8. **Health probes** — exclude `/healthz` and `/readyz` from span creation and metric observations.
9. **Sampling** — use tail-based sampling; always keep errors and latency outliers; include `sample_rate` on every event.

## Verifying compliance

Confirm spans reach the collector:

```bash
curl -s http://your-collector:4318/v1/traces | jq '.resourceSpans[0].resource.attributes'
```

Confirm health probes are excluded from traces by checking no spans appear for `/healthz` after making requests to it.
