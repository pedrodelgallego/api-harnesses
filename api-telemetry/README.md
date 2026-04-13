# api-telemetry

Logs alone can't tell you where a request spent its time across services. Without traces you can't follow a request across boundaries; without metrics you can't alert on SLO burn. Without correlation across all three signals, incidents are guesswork. This harness defines what must be collected and how — 13 ERROR-level rules — using OpenTelemetry so vendor choice stays separate from instrumentation.

## Who should use it

Any team operating services in production who needs request tracing, SLO-based alerting, and the ability to link a support ticket to a specific distributed trace. Language and framework agnostic; compose with a language-specific blueprint, which wires the framework's OTel integration; this harness defines the contract.

## How to use it

Add as a dependency in your blueprint spec or reference directly. The violations table — 13 ERROR, 2 SHOULD NOT — drives code review and CI policy checks. The Collector pipeline rules apply to infrastructure configuration, not application code.

## What it contains

- **Signal requirements** — all three signals (traces, metrics, logs) from every service; OTLP only; OTel Collector as sole export point, never write directly to Prometheus or Jaeger from app code
- **SDK initialization** — single `Meter` and `Tracer` at startup, never per-request; framework's official OTel integration, never raw SDK in route handlers; required Resource attributes: `service.name`, `service.version`, `deployment.environment`, `service.team`, `git_hash`
- **Wide structured events** — root span as primary artifact; request context, feature flags, timing summaries, and async rollups attached as span attributes, not child spans
- **Spans** — named by route template (`GET /users/:id`), never resolved URL; ERROR status on 5xx only, never on 4xx; Span Links for async boundaries; health probes excluded
- **Trace propagation** — W3C `traceparent`/`tracestate` on all outbound calls; `trace_id` and `span_id` on every log entry within a request context
- **Metrics** — lowercase dot-notation with unit suffix; Histogram for latency and size, never Counter where Histogram applies; no high-cardinality values as dimensions
- **Sampling** — tail-based required; errors and latency outliers always kept; `sample_rate` on every emitted event
