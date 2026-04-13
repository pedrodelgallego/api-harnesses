# rust-api-blueprint

`unwrap()` in a handler turns a type-safe codebase into one that panics under unexpected input. Storing JWT claims in a string-keyed extension map loses type safety at the HTTP boundary. Bypassing sqlx's `query!` macros defeats compile-time SQL checking. This blueprint fixes the idiomatic choices and bans the patterns that undermine Rust's guarantees end to end.

## Who should use it

Teams or individuals building REST APIs in Rust stable who want strong type safety, zero-copy deserialization, and compile-time-checked SQL. Best for performance-sensitive services, infrastructure tooling, and security-critical APIs.

## How to use it

Pull the spec into specforge or pass it to a code-generation agent. All eight cross-cutting harnesses (design, resilience, security, security headers, logging, telemetry, testing, versioning) are composed in as dependencies.

## What it contains

- **Stack** — Rust stable; Tokio; Axum never Actix-web or Warp; Tower; sqlx with `query!` macros never SeaORM or Diesel; `validator` crate with `#[derive(Validate)]`; `jsonwebtoken` for validation only; `tracing` + `tracing-subscriber` never the `log` crate; `envy` + serde for config; `tower::ServiceExt::oneshot()` in tests never a real `TcpListener`; sqlx migrate; utoipa
- **Project structure** — `src/main.rs` entry only; `src/app.rs` Router (no bind); `src/server.rs` shutdown; `src/config.rs`; `src/error.rs` AppError implementing `IntoResponse`; `src/routes/`; `src/middleware/`; `src/service/`; `src/model/`; `src/db/` (migrations/, queries/)
- **Security** — Tower layer registration order enforced; JWT claims in typed extensions, never string map; `unwrap()`/`expect()` banned in handler and service code; CORS with explicit origin allowlist
- **Middleware registration order** — Tower layers ordered: tracing → correlation ID → security headers → CORS → rate limiting → auth → routes
- **Routes** — `/v1` prefix from first commit; validated extractor before any field access; `bodyLimit` configured; no business logic in handlers
- **Validation & serialization** — `#[derive(Validate)]` on all request types; validated extractor as the first extractor in every handler; validation errors translated to RFC 7807 format
- **Logging** — `tracing` only; `tracing-subscriber` with JSON in production; correlation ID as span field; no output in tests via `tracing_subscriber::fmt().with_writer(io::sink())`
- **Lifecycle & resilience** — `shutdown_signal()` future handling SIGTERM and SIGINT; hard timeout from `DRAIN_TIMEOUT_MS`; `/healthz` and `/readyz` exposed; `pool.acquire_timeout` returns 503 on exhaustion
- **Telemetry** — `tracing-opentelemetry` bridge; tracer provider initialized before router; shutdown in graceful shutdown sequence; health probes excluded
- **Configuration** — `envy` + serde; hard-fail on missing vars; config struct injected into app factory for test overrides
- **Database** — `query!` macros only, never raw string queries; migrations via `sqlx migrate`; `PgPoolOptions` with pool sizing and `acquire_timeout`
- **OpenAPI documentation** — utoipa derive macros on every handler and model; Swagger UI disabled in production; `#[utoipa::path(security(("bearerAuth" = [])))]` on protected routes
- **Testing** — `tower::ServiceExt::oneshot()` for all route tests; testcontainers Postgres for integration tests; 100% coverage on `routes/` and `service/`
