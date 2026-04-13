# Rust API Blueprint

## Stack
- MUST use Rust (latest stable).
- MUST use Tokio as the async runtime. NEVER async-std.
- MUST use Axum as the framework. NEVER Actix-web. NEVER Warp. NEVER Rocket.
- MUST use the `validator` crate with `#[derive(Validate)]` for validation. NEVER manual field checks.
- MUST use sqlx with `query!` macros for the query layer. NEVER SeaORM. NEVER Diesel. NEVER raw string queries.
- MUST use `jsonwebtoken` crate for JWT validation only. NEVER issue tokens from app code; use an IDaaS provider.
- MUST use `tracing` + `tracing-subscriber` for logging. NEVER `log`. NEVER `env_logger` directly.
- MUST use `envy` + `serde::Deserialize` for config. NEVER `std::env::var()` scattered across modules.
- MUST use `tower::ServiceExt::oneshot()` for testing. NEVER a real `TcpListener` in unit/integration tests.
- MUST use `sqlx migrate` (built-in CLI) for migrations. NEVER hand-applied SQL.

## Project Structure

MUST follow this layout exactly:

- `src/main.rs` — Calls `server::start()`. ONLY entry point that binds a port.
- `src/app.rs` — Builds and returns the `axum::Router`. NO `TcpListener` bind.
- `src/server.rs` — Binds the port and owns graceful shutdown.
- `src/config.rs` — Env-driven config struct; parsed and validated at startup.
- `src/routes/` — One file per resource; returns a `Router` mounted in `app.rs`.
- `src/middleware/` — Tower-compatible middleware functions and layers.
- `src/service/` — Business logic. Handlers NEVER contain business logic.
- `src/model/` — Request/response structs with `Validate`, `Serialize`, `Deserialize` derives.
- `src/error.rs` — Unified `AppError` type implementing `IntoResponse`.
- `src/db/` — sqlx pool setup, `migrations/`, `queries/*.sql`.

## Security

Implements [api-security harness](../../api-security/harness/index.md) and [api-security-headers harness](../../api-security-headers/harness/index.md).

Rust-specific implementation:

- Add `tower_http::cors::CorsLayer` with an explicit `allow_origin` list from config — NEVER `CorsLayer::permissive()` on authenticated routes.
- Add `tower_http::set_header::SetResponseHeaderLayer` for security headers (X-Content-Type-Options, X-Frame-Options, etc.).
- Rate limit with `governor` crate via a custom Tower layer; back with Redis for multi-instance deployments.
- Verify JWT in an `axum::middleware::from_fn` extractor; insert decoded claims into request extensions via `request.extensions_mut().insert(claims)` — NEVER use a string-keyed map. NEVER extract JWT claims from request extensions without type-safe unwrapping.
- Use `tower_http::limit::RequestBodyLimitLayer` globally.
- NEVER ship a handler without a validated extractor.
- NEVER return a raw error message directly in a JSON response body.
- NEVER call `unwrap()` or `expect()` in handler or service code.

## Middleware Registration Order

MUST layer middleware on the root `Router` in this order (outermost first):

1. `TraceLayer` (tracing/logging)
2. Correlation ID (custom middleware — see Logging)
3. `TimeoutLayer`
4. `RequestBodyLimitLayer`
5. `CompressionLayer`
6. CORS (`CorsLayer`)
7. Security headers (`SetResponseHeaderLayer`)
8. Rate limiter (governor layer)
9. Route groups

Protected route groups MUST apply the JWT middleware via `.route_layer(middleware::from_fn(auth_middleware))` — NEVER inline auth checks inside handlers.

## Routes

Implements [api-versioning harness](../../api-versioning/harness/index.md). MUST prefix all routes with `/v1` from day one:

```rust
pub fn router() -> Router<AppState> {
    Router::new().nest("/v1", routes::all())
}
```

MUST define a typed extractor struct for every write route's request body using `axum::Json<T>` where `T: Validate + Deserialize`. MUST call `.validate()` immediately after extraction — NEVER use the inner value before validation.

MUST set a per-route body size limit via `DefaultBodyLimit::max(BODY_LIMIT)` as a route layer where a stricter limit than the global default is needed:

```rust
const BODY_LIMIT: usize = 1 << 20; // 1 MB
.route("/upload", post(handler).layer(DefaultBodyLimit::max(BODY_LIMIT)))
```

NEVER put business logic in handlers — delegate to a service function.

## Validation & Serialization

All request structs MUST derive `Validate` and `Deserialize`. All response structs MUST derive `Serialize`. NEVER use `serde_json::Value` as a request or response type.

- NEVER use request fields before calling `.validate()` in a handler.
- NEVER ship a response struct without `#[serde(rename_all = "camelCase")]` or explicit field names.
- NEVER return validation errors verbatim (internal field names must not be exposed).
- NEVER use `serde_json::Value` as a handler parameter or return type.

### Validator Configuration

MUST call `req.validate()` at the top of every write handler and map the error to `AppError::Validation` — NEVER let `ValidationErrors` reach the response serializer directly.

### Error Formatting

MUST define a single `AppError` enum in `src/error.rs` implementing `IntoResponse`. All handler and service functions MUST return `Result<T, AppError>`. NEVER return `StatusCode` alone from a handler — always pair with a structured body.

```rust
#[derive(Serialize)]
pub struct ErrorBody {
    pub errors: Vec<FieldError>,
}

#[derive(Serialize)]
pub struct FieldError {
    pub field: String,
    pub message: String,
}
```

NEVER expose Rust type names, module paths, or raw `validator` error keys to clients.

## Logging

Implements [api-logging harness](../../api-logging/harness/index.md). Rust-specific setup:

MUST use `tracing` for all instrumentation and `tracing-subscriber` for output formatting. NEVER call `println!` or `eprintln!` in application code.

MUST initialize a single `tracing::Subscriber` in `main.rs` before building the app:

- In production: `tracing_subscriber::fmt().json()` — structured JSON output
- In development: `tracing_subscriber::fmt().pretty()`
- In tests: `tracing_subscriber::fmt().with_writer(std::io::sink())` — discard all output

MUST set log level from the `LOG_LEVEL` env var via `tracing_subscriber::EnvFilter`. Default `info` in production, `debug` in development.

MUST add `tower_http::trace::TraceLayer` to the router for automatic HTTP request/response tracing.

MUST generate or propagate a correlation ID in middleware and insert it into the tracing span:

```rust
let correlation_id = headers
    .get("x-correlation-id")
    .and_then(|v| v.to_str().ok())
    .map(str::to_owned)
    .unwrap_or_else(|| Uuid::new_v4().to_string());
tracing::Span::current().record("correlation_id", &correlation_id);
```

MUST echo `X-Correlation-ID` on every response. MUST include `correlation_id` and `service` in every structured log entry.

MUST redact `authorization`, `cookie`, `password`, `token`, and `secret` fields — NEVER log them verbatim. Use `tracing`'s field-level redaction or strip before logging.

## Lifecycle & Resilience

Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md). Rust-specific implementation:

**Shutdown:**

MUST use Axum's built-in graceful shutdown via `.with_graceful_shutdown(shutdown_signal())`:

```rust
async fn shutdown_signal() {
    let ctrl_c = async { signal::ctrl_c().await.expect("ctrl-c handler") };
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("SIGTERM handler")
            .recv()
            .await
    };
    tokio::select! { _ = ctrl_c => {}, _ = terminate => {} }
}
```

MUST enforce a drain timeout via `DRAIN_TIMEOUT_MS` env var (default 10 s). Wrap the shutdown future with `tokio::time::timeout` — NEVER rely on OS-level kill after signal.

MUST log `fatal` and exit with code 1 if the drain timeout fires before shutdown completes.

**Health & Readiness:**

MUST expose `GET /healthz` and `GET /readyz`. MUST skip auth, rate limiting, and tracing on both. Mount them outside the `/v1` prefix and outside the auth layer.

**DB Pool:**

MUST size via `PgPoolOptions::new().max_connections((2 * num_cpus::get() + 1) as u32)`. MUST set `.acquire_timeout(Duration::from_secs(2))` — return `503` immediately on pool exhaustion. NEVER queue indefinitely.

## Telemetry

Implements [api-telemetry harness](../../api-telemetry/harness/index.md). Rust-specific setup:

MUST use `opentelemetry` + `opentelemetry-otlp` + `tracing-opentelemetry` to bridge `tracing` spans to OTEL.

MUST initialize the tracer provider in `main.rs` before building the app. MUST call `global::shutdown_tracer_provider()` in the graceful shutdown sequence.

MUST instrument the Axum router with `tower_http::trace::TraceLayer` configured to emit OTEL-compatible spans.

MUST skip tracing on `/healthz` and `/readyz` by excluding them from the `TraceLayer`.

## Configuration

MUST load all config from environment variables using `envy`:

```rust
#[derive(Deserialize)]
pub struct Config {
    pub port: u16,
    pub database_url: String,
    pub jwt_secret: String,
    pub allowed_origins: String, // comma-separated, split at startup
    #[serde(default = "default_log_level")]
    pub log_level: String,
    #[serde(default = "default_drain_timeout")]
    pub drain_timeout_ms: u64,
}

pub fn load() -> Result<Config, envy::Error> {
    envy::from_env::<Config>()
}
```

MUST call `config::load()` in `main.rs` and hard-fail on error — NEVER silently fall back to defaults for required fields.

NEVER use `std::env::var()` inside handlers, services, or middleware. MUST pass `Config` (or a sub-struct) via `axum::extract::State` — NEVER use global statics for config.

MUST accept `Config` as a parameter in `build_app(cfg: Config, pool: PgPool) -> Router`. This enables per-test config injection without mutating environment variables.

NEVER use `.env` files in production — use secrets manager injection.

## Database

MUST define all schema in `src/db/migrations/` as numbered `.sql` files. MUST run `sqlx migrate run` at startup before serving requests.

MUST write all queries in `src/db/queries/*.sql` and use the `sqlx::query!` or `sqlx::query_as!` macros — NEVER construct SQL strings with format macros or string concatenation.

MUST use `sqlx::query!` compile-time checking. MUST set `DATABASE_URL` at build time for `cargo sqlx prepare` — NEVER skip this step before committing.

MUST wrap multi-step operations in a transaction via `pool.begin()` — NEVER leave partial writes on failure.

## OpenAPI Documentation

MUST annotate every handler with `#[utoipa::path(...)]` and every model with `#[derive(ToSchema)]`. MUST register all paths and schemas in a top-level `ApiDoc` struct using `utoipa::OpenApi`.

MUST mount `utoipa-swagger-ui` in `app.rs` — after security middleware, before route groups.

MUST disable Swagger UI in production (guard with `cfg.env != "production"`) or protect it with authentication. NEVER expose API docs publicly in production.

MUST add `security([("bearerAuth", [])])` to all protected route annotations.

## Testing

Implements [api-testing harness](../../api-testing/harness/index.md). Rust-specific rules:

- NEVER test a route handler with a real `TcpListener` bind.
- NEVER mock the DB in integration tests — MUST use a real Postgres instance.
- NEVER call `std::env::var()` inside a test — MUST inject config via `build_app`.
- NEVER call `unwrap()` on a response in a test without asserting status first.

MUST use `tower::ServiceExt::oneshot()` for all route tests:

```rust
let app = build_app(test_config(), pool.clone());
let response = app
    .oneshot(Request::builder().uri("/v1/users").body(Body::empty()).unwrap())
    .await
    .unwrap();
assert_eq!(response.status(), StatusCode::OK);
```

MUST pass a test-specific `Config` into `build_app` — NEVER mutate environment variables in tests.

MUST initialize tracing with `std::io::sink()` writer in all tests — NEVER emit log output during test runs.

MUST run integration tests against a real Postgres instance (`testcontainers` crate) — NEVER mock sqlx queries for integration tests.

MUST reset database state between tests — use a transaction per test that is rolled back on drop, or truncate tables in a `before_each` equivalent.

MUST achieve 100% coverage on lines, branches, and functions across `src/routes/` and `src/service/` modules. Exclude `src/main.rs` and generated migration code from coverage requirements.
