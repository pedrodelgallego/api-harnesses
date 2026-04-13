# go-api-blueprint

Go's ecosystem has competing choices for routing, persistence, and logging. Leaving them open per-project fragments the organization: different routers mean different middleware patterns, different loggers mean different log shapes. This blueprint fixes the entire stack so any Go API written against it is immediately navigable by any Go engineer.

## Who should use it

Teams or individuals building REST APIs in Go 1.22+. Best for new services, multi-service organizations where engineers work across repos, and any project where consistent structure matters.

## How to use it

Pull the spec into specforge or pass it to a code-generation agent. All eight cross-cutting harnesses (design, resilience, security, security headers, logging, telemetry, testing, versioning) are composed in as dependencies.

## What it contains

- **Stack** — Go 1.22+; Chi v5 never Gin or Echo; `go-playground/validator` v10 with struct tags; sqlc with `.sql` query files never GORM; `golang-jwt/jwt` v5 for validation only; `log/slog` never zap or logrus; `caarlos0/env` for config; `httptest.NewRecorder()` never a real listener; goose for migrations; swaggo for OpenAPI
- **Project structure** — `cmd/api/main.go` entry only; `internal/app/app.go` router (no bind); `internal/server/server.go` shutdown; `internal/config`, `handler`, `middleware`, `service`, `model`, `db` (schema.sql, queries/, migrations/)
- **Security** — `go-chi/cors` with explicit `AllowedOrigins` from config; `go-chi/httprate` with Redis store; JWT in context with typed keys, never string keys; `unrolled/secure` for security headers
- **Router & middleware registration order** — RealIP → RequestID → Correlation ID → logger → Recoverer → CORS → security headers → rate limiter → route groups; protected sub-routers use `.With(AuthMiddleware)`
- **Routes** — `/v1` prefix from first commit; validated request struct and response struct for every route; `validate.Struct()` at the top of every write handler; `middleware.RequestSize(maxBodyBytes)` on every route that accepts a body; no business logic in handlers
- **Validation & serialization** — `validator.New()` instantiated once at startup; `RegisterTagNameFunc` maps to `json` tag names; `ValidationErrors` translated to normalized `{ "errors": [{ "field", "message" }] }` response
- **Logging** — `log/slog` only; single `slog.Logger` via dependency injection, never `slog.Default()` in handlers; `io.Discard` in tests; JSON handler in production, text in development; correlation ID bound per request
- **Lifecycle & resilience** — `signal.NotifyContext` for SIGTERM/SIGINT; `srv.Shutdown(ctx)` with deadline from `DRAIN_TIMEOUT_MS` parsed as integer; `/healthz` and `/readyz` without auth or rate limiting; DB pool sized `(2 × NumCPU) + 1`; 503 immediately on pool exhaustion
- **Telemetry** — `otelhttp` Chi instrumentation; tracer provider initialized before router; shutdown before `os.Exit`; `/healthz` and `/readyz` excluded
- **Configuration** — `caarlos0/env` struct tags with `required`; hard-fail on missing vars; `NewApp(cfg *Config)` for test injection without mutating `os.Environ`
- **Database** — schema in `schema.sql`; queries in `queries/*.sql`; `sqlc generate` produces Go code; goose migrations; parameterized queries enforced by sqlc; multi-step operations wrapped in transactions
- **OpenAPI documentation** — swaggo annotations on every handler and model; `httpSwagger.WrapHandler` after security middleware; Swagger UI disabled in production or behind auth; `@Security BearerAuth` on protected routes
- **Testing** — `httptest.NewRecorder()` for all route tests; real Postgres in Docker for integration tests, never mock sqlc interfaces; config injected via `NewApp`; `io.Discard` logger; 100% coverage on `handler/` and `service/`
