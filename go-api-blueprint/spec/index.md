# Go API Blueprint

## Stack
- MUST use Go 1.22+.
- MUST use Chi (`github.com/go-chi/chi/v5`). NEVER Gin, NEVER Echo, NEVER Fiber.
- MUST use `go-playground/validator/v10` via struct tags. NEVER manual field checks.
- MUST use sqlc. NEVER GORM, NEVER raw `db.QueryRow()` with interpolated input.
- MUST use `golang-jwt/jwt/v5` for JWT validation only. NEVER issue tokens from app code; use an IDaaS provider.
- MUST use `log/slog` (stdlib). NEVER zap, NEVER logrus, NEVER zerolog.
- MUST use `github.com/caarlos0/env/v11` with struct tags. NEVER `os.Getenv()` scattered across packages.
- MUST use `net/http/httptest` + `testify`. NEVER a real listening server in tests.
- MUST use `github.com/pressly/goose/v3`. NEVER hand-applied SQL.

## Project Structure

MUST follow this layout exactly:

- `cmd/api/main.go` — Calls `server.Start()`. ONLY entry point that binds a port.
- `internal/app/app.go` — Builds and returns the `chi.Router`. NO `ListenAndServe` call.
- `internal/server/server.go` — Calls `http.ListenAndServe` and owns graceful shutdown.
- `internal/config/config.go` — Env-driven config struct; parsed and validated at startup.
- `internal/handler/` — One file per resource; registers routes on a sub-router.
- `internal/middleware/` — Chi-compatible middleware functions.
- `internal/service/` — Business logic. Handlers NEVER contain business logic.
- `internal/model/` — Request/response structs with `validate` and `json` tags.
- `internal/db/` — sqlc-generated code, `schema.sql`, `queries/`, `migrations/`.

## Security

Implements [api-security harness](../../api-security/harness/index.md) and [api-security-headers harness](../../api-security-headers/harness/index.md).

Go-specific implementation:

- Register `github.com/go-chi/cors` with an explicit `AllowedOrigins` list from config. NEVER use `AllowedOrigins: []string{"*"}` on authenticated routes.
- Register `github.com/go-chi/httprate` globally with a Redis store; override per-route where needed.
- Verify JWT on every protected route via a middleware; store decoded claims in `context.Context` under a typed key. NEVER a string key. NEVER read JWT claims from context without a type assertion guard.
- Use `github.com/unrolled/secure` for security headers.
- NEVER ship a handler without a validated request struct.
- NEVER return raw error strings directly in a JSON response body.

## Router & Middleware Registration Order

MUST mount middleware in this order on the root router:

1. `middleware.RealIP`
2. `middleware.RequestID`
3. Correlation ID (custom — see Logging)
4. Structured logger
5. `middleware.Recoverer`
6. CORS
7. Security headers
8. Rate limiter
9. Route groups

Sub-routers for protected routes MUST use `.With(AuthMiddleware)`. NEVER inline auth checks inside handlers.

## Routes

Implements [api-versioning harness](../../api-versioning/harness/index.md). MUST prefix all routes with `/v1` from day one via a sub-router:

```go
r.Route("/v1", func(r chi.Router) {
    handler.RegisterUserRoutes(r)
})
```

MUST define a request struct and a response struct for every route in `internal/model/`.

MUST call `render.DecodeJSON(r.Body, &req)` then `validate.Struct(&req)` at the top of every write handler. NEVER trust unvalidated input.

MUST set a body size limit on every route that accepts a body:

```go
const maxBodyBytes = 1 << 20 // 1 MB
r.With(middleware.RequestSize(maxBodyBytes)).Post("/users", h.Create)
```

NEVER put business logic in handlers — delegate to a service function.

## Validation & Serialization

All request structs MUST carry `validate` tags. All response structs MUST carry `json` tags with `omitempty` omitted on required fields. NEVER leak zero-value fields as `null` or `0` unintentionally.

- NEVER read fields from an unvalidated struct in a handler.
- NEVER call `json.Marshal` on a struct without defined `json` tags.
- NEVER return validation errors verbatim from `validator` to the client.
- NEVER use `interface{}` or `any` as a response payload type.

### Validator Configuration

MUST instantiate `validator.New()` once at app startup and pass it through dependency injection. NEVER call `validator.New()` inside a handler.

MUST register `validate.RegisterTagNameFunc` to use `json` tag names in error messages so field names match the wire format.

### Error Formatting

MUST translate `validator.ValidationErrors` into a normalized error response:

```go
type FieldError struct {
    Field   string `json:"field"`
    Message string `json:"message"`
}
type ValidationError struct {
    Errors []FieldError `json:"errors"`
}
```

NEVER expose Go struct field names or raw validator tag strings to clients.

## Logging

Implements [api-logging harness](../../api-logging/harness/index.md). Go-specific setup:

MUST use `log/slog` exclusively. NEVER add other logging libraries.

MUST configure a single `slog.Logger` in `config.go` and pass it via dependency injection. NEVER use `slog.Default()` inside handlers or services.

- `level`: from `LOG_LEVEL` env var; default `INFO` in production, `DEBUG` in development
- In development, use `slog.NewTextHandler`; in production, use `slog.NewJSONHandler`
- NEVER log during tests — pass a `slog.New(slog.NewTextHandler(io.Discard, nil))` logger

MUST generate or propagate a correlation ID in a middleware and store it on the request context:

```go
func CorrelationID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Correlation-ID")
        if id == "" {
            id = uuid.NewString()
        }
        ctx := context.WithValue(r.Context(), correlationIDKey, id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

MUST echo `X-Correlation-ID` on every response. MUST include `correlationId` and `service` in every structured log entry.

MUST redact `Authorization`, `Cookie`, `password`, `token`, and `secret` fields before logging. NEVER log them verbatim.

## Lifecycle & Resilience

Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md). Go-specific implementation:

**Shutdown:**

MUST handle `SIGTERM` and `SIGINT` in `server.go` via `signal.NotifyContext`.

MUST call `server.Shutdown(ctx)` with a deadline. NEVER `os.Exit()` directly:

```go
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
defer stop()
<-ctx.Done()

shutdownCtx, cancel := context.WithTimeout(context.Background(), drainTimeout)
defer cancel()
if err := srv.Shutdown(shutdownCtx); err != nil {
    slog.Error("shutdown error", "err", err)
    os.Exit(1)
}
```

MUST read `DRAIN_TIMEOUT_MS` env var for the drain deadline (default 10 s). MUST parse it as integer. NEVER pass raw string to `time.Duration`.

**Health & Readiness:**

MUST expose `GET /healthz` and `GET /readyz`. MUST skip auth and rate limiting on both. MUST exclude them from access logs.

**DB Pool:**

MUST size the connection pool to `(2 × runtime.NumCPU()) + 1` via `db.SetMaxOpenConns`. MUST set `db.SetMaxIdleConns` to the same value. MUST set `db.SetConnMaxLifetime(1 * time.Hour)`.

MUST return `503` immediately when the pool is exhausted. NEVER queue indefinitely. Implement via a context deadline on every query.

## Telemetry

Implements [api-telemetry harness](../../api-telemetry/harness/index.md). Go-specific setup:

MUST use `go.opentelemetry.io/otel` with the OTLP exporter.

MUST initialize the tracer provider before building the router in `main.go`. MUST call `shutdown()` in the graceful shutdown sequence before `os.Exit`.

MUST instrument Chi with `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp`.

MUST skip tracing on `/healthz` and `/readyz`.

## Configuration

MUST load all config from environment variables using `github.com/caarlos0/env/v11`:

```go
type Config struct {
    Port          int           `env:"PORT,required"`
    DatabaseURL   string        `env:"DATABASE_URL,required"`
    JWTSecret     string        `env:"JWT_SECRET,required"`
    AllowedOrigins []string     `env:"ALLOWED_ORIGINS,required" envSeparator:","`
    LogLevel      string        `env:"LOG_LEVEL" envDefault:"info"`
    DrainTimeout  int           `env:"DRAIN_TIMEOUT_MS" envDefault:"10000"`
}
```

MUST hard-fail on startup if any `required` env var is missing.

NEVER use `.env` files in production — use secrets manager injection.

MUST accept a `*Config` as a parameter in `NewApp(cfg *Config, ...)`. NEVER read `os.Getenv` inside handlers or services. This enables per-test config injection without mutating the environment.

## Database

MUST define all schema in `internal/db/schema.sql`. MUST write all queries in `internal/db/queries/*.sql`. MUST run `sqlc generate` to produce Go code. NEVER hand-write query functions.

MUST use goose for migrations. Migration files live in `internal/db/migrations/`.

MUST use parameterized queries exclusively — sqlc enforces this. NEVER call `db.QueryContext` with string concatenation.

MUST wrap multi-step operations in a transaction using the sqlc-generated `WithTx` pattern. NEVER leave partial writes on failure.

## OpenAPI Documentation

MUST annotate every handler and model with swaggo comments. MUST run `swag init` to regenerate `docs/`. NEVER edit generated files by hand.

MUST mount `httpSwagger.WrapHandler` in `app.go` — after security middleware, before route groups.

MUST disable Swagger UI in production (guard with `cfg.Env != "production"`) or protect it with authentication. NEVER expose API docs publicly in production.

MUST add `@Security BearerAuth` to all protected route annotations.

## Testing

Implements [api-testing harness](../../api-testing/harness/index.md). Go-specific rules:

- NEVER test a route handler with a real `net.Listen` call. MUST use `httptest.NewRecorder()` and call the handler directly.
- NEVER mock the DB in integration tests. MUST use a real Postgres instance.
- NEVER call `os.Getenv` inside a test. MUST inject config via `NewApp`.

MUST accept `*Config` in `NewApp` for test config injection.

MUST set the logger to `slog.New(slog.NewTextHandler(io.Discard, nil))` in all tests.

MUST run integration tests against a real Postgres instance (Docker / testcontainers-go). NEVER mock sqlc-generated interfaces for integration tests.

MUST reset database state in `TestMain` or per-test with truncation. NEVER rely on test execution order.

MUST achieve 100% coverage on lines, branches, and functions across `internal/handler/` and `internal/service/` packages. Exclude `cmd/` and generated `internal/db/` from coverage requirements.
