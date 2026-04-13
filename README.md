# API Harnesses

Spec packages published to **SpecHub** to help AI coding agents align with engineering standards. Each package contains machine-checkable rules, examples, and guidance that agents consume at code-generation time.

## Packages

### Standards

| Package | Description |
|---|---|
| `api-rest-design` | URL structure, status codes, and error format — 17 rules |
| `api-rest-resilience` | Timeouts, retries, and circuit breakers — 14 rules |
| `api-security` | Auth, JWT handling, and ID safety — 22 rules |
| `api-security-headers` | CORS, cache, and HTTP security headers — 9 rules |
| `api-logging` | Log fields, correlation, and PII masking — shared contract |
| `api-telemetry` | Traces, metrics, and OpenTelemetry instrumentation — 13 rules |
| `api-testing` | Test pyramid, real DB, and assertion depth — 7 rules |
| `api-versioning` | Version prefixes and deprecation lifecycle — 5 rules |

### Blueprints

| Package | Stack | Description |
|---|---|---|
| `fastify-api-blueprint` | Node.js / Fastify | TypeBox schemas, `inject()` testing, no logic in handlers |
| `go-api-blueprint` | Go | Fixed router, logger, and persistence stack |
| `kotlin-api-blueprint` | Kotlin / Ktor | Coroutine-native with Exposed, no JPA |
| `python-api-blueprint` | Python / FastAPI | Async-safe patterns for config, DB, and log context |
| `rust-api-blueprint` | Rust / Axum | No `unwrap()` in handlers, typed extensions, sqlx macros |
| `springboot-kotlin-api-blueprint` | Kotlin / Spring Boot | JPA pitfalls avoided, CORS via filter chain |
