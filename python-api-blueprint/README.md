# python-api-blueprint

Python's async ecosystem has sharp edges: blocking psycopg2 calls block the event loop silently, scattered `os.getenv` makes config untestable, and structlog context leaks across recycled async tasks. This blueprint encodes the working async patterns so a new service handles startup, shutdown, config injection, and log context correctly from the first commit.

## Who should use it

Teams or individuals building REST APIs with Python 3.12+. Best for data platform teams, ML inference services, and internal tooling where Python's ecosystem (Pydantic, SQLAlchemy, structlog) is the right fit.

## How to use it

Pull the spec into specforge or pass it to a code-generation agent. All eight cross-cutting harnesses (design, resilience, security, security headers, logging, telemetry, testing, versioning) are composed in as dependencies.

## What it contains

- **Stack** — Python 3.12+; FastAPI never Django REST Framework or Flask; Pydantic v2 never Marshmallow; Pydantic Settings with `lru_cache`; SQLAlchemy 2.0 async Core never ORM mapped classes; asyncpg never blocking psycopg2; PyJWT for validation only; structlog with contextvars; Alembic; slowapi + Redis; httpx `AsyncClient` + `ASGITransport` in tests; testcontainers-python; pytest-cov; uv
- **Project structure** — `src/app/main.py` uvicorn entry only; `src/app/app.py` `create_app()` factory; `src/app/config.py` Pydantic Settings + `lru_cache`; `src/app/dependencies.py` Depends callables; `routers/` one per resource; `middleware/`; `services/`; `models/`; `db/` (engine.py, tables.py, queries/, migrations/)
- **Security** — middleware registration order enforced; JWT via `Depends(get_current_user)`, never manual header parsing; `extra="forbid"` on all request models; `bodyLimit` configured per endpoint
- **Middleware registration order** — CORS → security headers → rate limiting → correlation ID → routes; order enforced
- **Routes** — `/v1` prefix from first commit; `response_model` on every route; `extra="forbid"` on all request models; no business logic in route functions
- **Validation & serialization** — Pydantic v2 with `extra="forbid"`; validation errors overridden to RFC 7807 format, never expose `loc` tuples to clients
- **Logging** — structlog with contextvars; `clear_contextvars()` per request (recycled async tasks leak context); JSON in production; silent in tests
- **Lifecycle & resilience** — `lifespan` context manager, never `@app.on_event`; uvicorn graceful shutdown via `DRAIN_TIMEOUT_MS`; `/healthz` and `/readyz` exposed; `pool_timeout=2` returns 503 on exhaustion
- **Telemetry** — `opentelemetry-sdk` + `opentelemetry-instrumentation-fastapi` + `opentelemetry-instrumentation-sqlalchemy`; wired in `lifespan`; OTLP export; health probes excluded
- **Configuration** — Pydantic Settings with `lru_cache`; injected via `Depends(get_settings)`; `dependency_overrides` for test injection; hard-fail on missing required fields
- **Database** — SQLAlchemy Core query functions in `db/queries/`; Alembic migrations; `create_async_engine` with pool sizing; never ORM mapped classes
- **OpenAPI documentation** — FastAPI auto-generation from type hints and `response_model`; `summary`, `description`, `tags` on every route; docs disabled or auth-protected in production
- **Testing** — `httpx.AsyncClient` + `ASGITransport` for route tests; testcontainers Postgres for integration tests; `dependency_overrides` for config injection; 100% coverage on `routers/` and `services/` via pytest-cov
