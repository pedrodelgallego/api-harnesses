# API Telemetry Harness

## Scope
These rules define traces, metrics, and log-trace correlation. Application log structure belongs in `api-logging.md`.

## Signals and Pipeline
- MUST emit traces and metrics from every service.
- SHOULD correlate logs with active traces.
- MUST use OpenTelemetry.
- MUST send telemetry through an OpenTelemetry Collector or equivalent gateway; MUST NOT export directly from every service to every backend unless explicitly approved.
- MUST initialize instrumentation before serving traffic.
- SHOULD disable telemetry in automated tests.

## Resource Attributes
- MUST define resource attributes once at startup.
- MUST include `service.name`, `service.version`, and `deployment.environment`.
- SHOULD include build identity and team ownership.
- MUST NOT duplicate stable resource attributes as high-cardinality span or metric dimensions.

## Spans
- MUST create spans for inbound HTTP requests, outbound HTTP/gRPC calls, DB calls, cache calls, message publish/consume, and background jobs.
- MUST NOT create spans for helper functions or tight loop iterations.
- MUST name HTTP server spans with route templates, not resolved URLs.
- MUST mark 5xx server spans as error.
- MUST NOT mark ordinary 4xx client-caused outcomes as error by default.
- MUST use span links for async boundaries when parent/child is not appropriate.

## Propagation
- MUST extract `traceparent` and `tracestate` on inbound requests.
- MUST propagate them on outbound requests.
- MUST attach `traceId` and `spanId` to request-scoped logs when a trace is active.

## Metrics
- MUST use low-cardinality dimensions only.
- MUST emit an HTTP request duration histogram.
- MUST use counters for monotonic counts, histograms for distributions, and gauges for current values.
- MUST avoid user IDs, full URLs, raw IDs, or other high-cardinality values as metric labels.

## Health Endpoints
- SHOULD suppress tracing and metrics for `/healthz` and `/readyz` unless there is a specific operational reason to keep them.

## Sampling
- SHOULD prefer tail-based sampling when supported.
- MUST retain error traces preferentially when sampling is enabled.
