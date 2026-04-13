# Go API Blueprint

## Scope
This file maps the general `api-*` harnesses to concrete Go implementation rules. It MUST NOT redefine the general API contract.

## Stack
- MUST use Go 1.22+.
- MUST use Chi (`github.com/go-chi/chi/v5`). NEVER Gin, NEVER Echo, NEVER Fiber.
- MUST use `go-playground/validator/v10` via struct tags. NEVER manual field checks.
- MUST use sqlc with `.sql` query files. NEVER GORM, NEVER raw `db.QueryRow()` with interpolated input.
- MUST use `golang-jwt/jwt/v5` for JWT validation only. NEVER issue tokens from app code.
- MUST use `log/slog` (stdlib). NEVER zap, NEVER logrus, NEVER zerolog.
- MUST use `github.com/caarlos0/env/v11` with struct tags. NEVER `os.Getenv()` scattered across packages.
- MUST use `net/http/httptest` + `testify` in tests. NEVER a real listening server.
- MUST use goose for migrations. NEVER hand-applied SQL.

## Project Structure
- `cmd/api/main.go` MUST be the only entry point that binds a port.
- `internal/app/app.go` MUST build and return the `chi.Router`. MUST NOT call `ListenAndServe`.
- `internal/server/server.go` MUST own graceful shutdown.
- `internal/config/config.go` — env-driven config struct; parsed and validated at startup.
- `internal/handler/` — one file per resource; registers routes on a sub-router.
- `internal/middleware/` — Chi-compatible middleware functions.
- `internal/service/` — business logic. Handlers MUST NOT contain business logic.
- `internal/model/` — request/response structs with `validate` and `json` tags.
- `internal/db/` — sqlc-generated code, `schema.sql`, `queries/`, `migrations/`.

## Middleware Registration Order
MUST mount middleware in this order on the root router:
1. `middleware.RealIP`
2. `middleware.RequestID`
3. Correlation ID (custom)
4. Structured logger
5. `middleware.Recoverer`
6. CORS
7. Security headers
8. Rate limiter
9. Route groups

Sub-routers for protected routes MUST use `.With(AuthMiddleware)`. NEVER inline auth checks inside handlers.

## Security
- MUST use `github.com/go-chi/cors` with an explicit `AllowedOrigins` list from config. NEVER `[]string{"*"}` on authenticated routes.
- MUST use `github.com/go-chi/httprate` globally with a Redis store.
- MUST use `github.com/unrolled/secure` for security headers.
- JWT claims MUST be stored in `context.Context` under a typed key. NEVER a string key.

## Routes
- All routes MUST be prefixed with `/v1` via a sub-router.
- Every write route MUST define a request struct and call `validate.Struct(&req)` before accessing any field.
- Every route that accepts a body MUST set a body size limit via `middleware.RequestSize`.

## Validation and Serialization
- `validator.New()` MUST be instantiated once at app startup and passed via dependency injection. NEVER called inside a handler.
- MUST register `RegisterTagNameFunc` to use `json` tag names in error messages.
- `validator.ValidationErrors` MUST be translated to a normalized `{ "errors": [{ "field", "message" }] }` response. NEVER expose raw validator tag strings to clients.

## Logging
- MUST use `log/slog` exclusively. NEVER add other logging libraries.
- MUST configure a single `slog.Logger` and pass it via dependency injection. NEVER use `slog.Default()` inside handlers or services.
- In production MUST use `slog.NewJSONHandler`; in development `slog.NewTextHandler`; in tests `slog.NewTextHandler(io.Discard, nil)`.
- MUST generate or propagate a correlation ID in middleware and store it on the request context.

## Resilience and Lifecycle
- MUST handle `SIGTERM` and `SIGINT` via `signal.NotifyContext` in `server.go`. NEVER `os.Exit()` directly.
- MUST call `srv.Shutdown(ctx)` with a deadline from `DRAIN_TIMEOUT_MS` parsed as integer.
- DB pool MUST be sized to `(2 × runtime.NumCPU()) + 1` via `db.SetMaxOpenConns`.

## Telemetry
- MUST use `go.opentelemetry.io/otel` with the OTLP exporter.
- MUST instrument Chi with `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp`.
- MUST initialize the tracer provider before building the router. MUST call `shutdown()` before `os.Exit`.

## Configuration
- MUST use `github.com/caarlos0/env/v11` struct tags with `required` for mandatory fields. Hard-fail on startup if any required var is missing.
- MUST accept `*Config` in `NewApp(cfg *Config, ...)`. NEVER read `os.Getenv` inside handlers or services.

## Database
- MUST define all schema in `internal/db/schema.sql` and queries in `internal/db/queries/*.sql`.
- MUST run `sqlc generate` to produce Go code. NEVER hand-write query functions.
- MUST use goose for migrations in `internal/db/migrations/`.
- MUST wrap multi-step operations in a transaction using the sqlc-generated `WithTx` pattern.

## OpenAPI
- MUST annotate every handler and model with swaggo comments. MUST run `swag init` to regenerate `docs/`.
- MUST add `@Security BearerAuth` to all protected route annotations.
- Swagger UI MUST be disabled in production or protected by authentication.

## Testing
- HTTP tests MUST use `httptest.NewRecorder()`. NEVER a real `net.Listen` call.
- MUST accept `*Config` in `NewApp` for test config injection.
- MUST use `slog.New(slog.NewTextHandler(io.Discard, nil))` as the logger in all tests.
- Integration tests MUST use a real Postgres instance (testcontainers-go). NEVER mock sqlc-generated interfaces.
- MUST achieve 100% coverage across `internal/handler/` and `internal/service/`. Exclude `cmd/` and generated `internal/db/`.
