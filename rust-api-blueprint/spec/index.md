# Rust API Blueprint

## Scope
This file maps the general `api-*` harnesses to concrete Axum/Rust implementation rules. It MUST NOT redefine the general API contract.

## Stack
- MUST use Rust (latest stable).
- MUST use Tokio as the async runtime. NEVER async-std.
- MUST use Axum. NEVER Actix-web, NEVER Warp, NEVER Rocket.
- MUST use the `validator` crate with `#[derive(Validate)]`. NEVER manual field checks.
- MUST use sqlx with `query!` macros. NEVER SeaORM, NEVER Diesel, NEVER raw string queries.
- MUST use `jsonwebtoken` for JWT validation only. NEVER issue tokens from app code.
- MUST use `tracing` + `tracing-subscriber`. NEVER the `log` crate or `env_logger` directly.
- MUST use `envy` + `serde::Deserialize` for config. NEVER `std::env::var()` scattered across modules.
- MUST use `tower::ServiceExt::oneshot()` in tests. NEVER a real `TcpListener`.
- MUST use `sqlx migrate` for migrations. NEVER hand-applied SQL.

## Project Structure
- `src/main.rs` MUST be the only entry point that binds a port.
- `src/app.rs` MUST build and return the `axum::Router`. MUST NOT bind a `TcpListener`.
- `src/server.rs` MUST own graceful shutdown.
- `src/config.rs` — env-driven config struct parsed at startup.
- `src/error.rs` — unified `AppError` type implementing `IntoResponse`.
- `src/routes/` — one file per resource; returns a `Router` mounted in `app.rs`.
- `src/middleware/` — Tower-compatible middleware.
- `src/service/` — business logic. Handlers MUST NOT contain business logic.
- `src/model/` — request/response structs with `Validate`, `Serialize`, `Deserialize` derives.
- `src/db/` — sqlx pool setup, `migrations/`, `queries/*.sql`.

## Middleware Registration Order
MUST layer middleware on the root `Router` in this order (outermost first):
1. `TraceLayer`
2. Correlation ID (custom middleware)
3. `TimeoutLayer`
4. `RequestBodyLimitLayer`
5. `CompressionLayer`
6. `CorsLayer`
7. `SetResponseHeaderLayer` (security headers)
8. Rate limiter (governor layer)
9. Route groups

Protected route groups MUST apply JWT middleware via `.route_layer(middleware::from_fn(auth_middleware))`. NEVER inline auth checks inside handlers.

## Security
- MUST use `tower_http::cors::CorsLayer` with an explicit `allow_origin` list. NEVER `CorsLayer::permissive()`.
- MUST use `tower_http::set_header::SetResponseHeaderLayer` for security headers.
- MUST use the `governor` crate for rate limiting backed by Redis.
- JWT claims MUST be inserted into request extensions via `request.extensions_mut().insert(claims)`. NEVER use a string-keyed map.
- `unwrap()` and `expect()` are BANNED in handler and service code.

## Routes
- All routes MUST be prefixed with `/v1`.
- Every write route MUST use a typed extractor `axum::Json<T>` where `T: Validate + Deserialize` and call `.validate()` immediately after extraction.

## Validation and Serialization
- All request structs MUST derive `Validate` and `Deserialize`. All response structs MUST derive `Serialize`.
- MUST call `req.validate()` at the top of every write handler and map errors to `AppError::Validation`.
- MUST define a single `AppError` enum in `src/error.rs` implementing `IntoResponse`. All handlers and service functions MUST return `Result<T, AppError>`.
- NEVER use `serde_json::Value` as a handler parameter or return type.

## Logging
- MUST use `tracing` for all instrumentation and `tracing-subscriber` for output.
- In production MUST use `tracing_subscriber::fmt().json()`; in development `fmt().pretty()`; in tests `fmt().with_writer(std::io::sink())`.
- MUST add `tower_http::trace::TraceLayer` to the router.
- MUST generate or propagate a correlation ID in middleware and insert it into the tracing span.

## Resilience and Lifecycle
- MUST use Axum's `.with_graceful_shutdown(shutdown_signal())` pattern handling `SIGTERM` and `SIGINT`.
- MUST enforce a drain timeout from `DRAIN_TIMEOUT_MS` via `tokio::time::timeout`. NEVER rely on OS-level kill.
- DB pool MUST use `PgPoolOptions` with `max_connections = (2 * num_cpus + 1)` and `acquire_timeout = 2s`.

## Telemetry
- MUST use `opentelemetry` + `opentelemetry-otlp` + `tracing-opentelemetry`.
- MUST initialize the tracer provider before building the app. MUST call `global::shutdown_tracer_provider()` in the shutdown sequence.

## Configuration
- MUST use `envy::from_env::<Config>()` in `main.rs` and hard-fail on error.
- MUST accept `Config` in `build_app(cfg: Config, pool: PgPool) -> Router`. NEVER use `std::env::var()` inside handlers, services, or middleware.

## Database
- MUST use `sqlx::query!` or `sqlx::query_as!` macros exclusively. NEVER construct SQL strings with format macros.
- MUST run `sqlx migrate run` at startup. MUST run `cargo sqlx prepare` and commit `.sqlx/` before pushing.
- MUST wrap multi-step operations in a transaction via `pool.begin()`.

## OpenAPI
- MUST annotate every handler with `#[utoipa::path(...)]` and every model with `#[derive(ToSchema)]`.
- Swagger UI MUST be disabled in production or protected by authentication.
- MUST add `security([("bearerAuth", [])])` to all protected route annotations.

## Testing
- MUST use `tower::ServiceExt::oneshot()` for all route tests. NEVER a real `TcpListener`.
- MUST pass a test-specific `Config` into `build_app`. NEVER mutate environment variables in tests.
- MUST initialize tracing with `std::io::sink()` writer in all tests.
- Integration tests MUST use a real Postgres instance via the `testcontainers` crate. NEVER mock sqlx queries.
- MUST achieve 100% coverage across `src/routes/` and `src/service/`. Exclude `src/main.rs` and generated migration code.
