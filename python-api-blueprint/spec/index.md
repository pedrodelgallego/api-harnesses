# Python API Blueprint

## Scope
This file maps the general `api-*` harnesses to concrete FastAPI/Python implementation rules. It MUST NOT redefine the general API contract.

## Stack
- MUST use Python 3.12+.
- MUST use FastAPI. NEVER Django REST Framework, NEVER Flask.
- MUST use Pydantic v2 for validation and serialization. NEVER Marshmallow, NEVER Cerberus.
- MUST use Pydantic Settings (`pydantic-settings`). NEVER `os.environ` / `os.getenv` scattered across modules.
- MUST use SQLAlchemy 2.0 async Core. NEVER ORM mapped classes, NEVER raw string queries.
- MUST use `asyncpg` as the DB driver. NEVER `psycopg2` (blocking).
- MUST use `PyJWT` for JWT validation only. NEVER issue tokens from app code.
- MUST use `structlog` with contextvars. NEVER `print`, NEVER stdlib `logging.basicConfig` directly.
- MUST use Alembic for migrations. NEVER hand-applied SQL.
- MUST use `slowapi` backed by Redis for rate limiting. NEVER in-memory rate limiting.
- MUST use `pytest` + `httpx.AsyncClient` via `ASGITransport` in tests. NEVER a real uvicorn server.
- MUST use `uv` for package management.

## Project Structure
- `src/app/main.py` MUST be the only file that calls `uvicorn.run()`.
- `src/app/app.py` MUST define `create_app()` factory and MUST NOT call `uvicorn.run()`.
- `src/app/config.py` — Pydantic `Settings` class loaded once via `lru_cache`.
- `src/app/dependencies.py` — FastAPI `Depends()` callables (auth, settings, db session).
- `src/app/routers/` — one file per resource; returns an `APIRouter`.
- `src/app/middleware/` — Starlette middleware classes.
- `src/app/services/` — business logic. Routers MUST NOT contain business logic.
- `src/app/models/` — Pydantic request and response models.
- `src/app/db/` — async engine, session factory, `queries/` subdirectory, `migrations/`.

## Middleware Registration Order
MUST add middleware in this order in `create_app()` (Starlette applies bottom-up):
1. `BodySizeLimitMiddleware` (innermost)
2. `SlowAPIMiddleware`
3. `SecurityHeadersMiddleware`
4. `CORSMiddleware`
5. `CorrelationIdMiddleware` (outermost)

Protected routers MUST use `dependencies=[Depends(get_current_user)]` at the router level. NEVER inline auth checks inside route functions.

## Security
- MUST use `CORSMiddleware` with an explicit `allow_origins` list from `Settings`. NEVER `["*"]`.
- JWT MUST be validated in a `get_current_user` dependency via `Depends()`. Decoded claims MUST be stored as a typed `TokenData` dataclass. NEVER a raw `dict`.
- MUST use `slowapi` `Limiter` globally backed by Redis.

## Routes
- All routes MUST be prefixed with `/v1`.
- Every route MUST declare `response_model`.
- All request models MUST set `model_config = ConfigDict(extra="forbid")`.
- NEVER put business logic in route functions.

## Validation and Serialization
- All request models MUST use `extra="forbid"` and `Field(...)` with explicit constraints.
- MUST override FastAPI's default `RequestValidationError` handler to return RFC 9457 format. NEVER expose Pydantic's internal `loc` tuples to clients.

## Logging
- MUST configure `structlog` once at startup in `create_app()`. NEVER call `structlog.configure()` inside a handler or service.
- MUST call `structlog.contextvars.clear_contextvars()` at the start of every request. NEVER leave context vars on a recycled async task.
- In production MUST use `JSONRenderer`; in development `ConsoleRenderer`; in tests silence via `CRITICAL` level.

## Resilience and Lifecycle
- MUST use FastAPI's `lifespan` context manager for all startup and shutdown logic. NEVER `@app.on_event`.
- MUST configure uvicorn graceful shutdown via `--timeout-graceful-shutdown` from `DRAIN_TIMEOUT_MS`.
- `create_async_engine` MUST set `pool_size=(2 * cpu_count) + 1`, `max_overflow=0`, `pool_timeout=2`.

## Telemetry
- MUST initialize the OTel SDK in the `lifespan` startup block. NEVER at module import time.
- MUST call `FastAPIInstrumentor().instrument_app(app)` after `create_app()` returns.
- MUST instrument SQLAlchemy with `SQLAlchemyInstrumentor().instrument(engine=engine)`.

## Configuration
- MUST use Pydantic Settings with `lru_cache` and inject via `Depends(get_settings)`. NEVER call `get_settings()` directly inside route functions or services.
- Test overrides MUST go via `app.dependency_overrides`. NEVER mutate environment variables in tests.

## Database
- MUST define table schemas as SQLAlchemy `Table` objects in `src/app/db/tables.py`.
- MUST write all queries as SQLAlchemy Core expressions in `src/app/db/queries/`. NEVER ORM `Session` or mapped classes.
- MUST run `alembic upgrade head` at startup in the `lifespan` block.
- NEVER use `text()` with f-strings or `.format()`.

## OpenAPI
- MUST add `summary`, `description`, and `tags` to every route decorator.
- Docs MUST be disabled in production (`docs_url=None, redoc_url=None`) or protected by authentication.

## Testing
- MUST use `httpx.AsyncClient` with `ASGITransport`. NEVER a real uvicorn server.
- MUST override `get_settings` via `app.dependency_overrides` in fixtures. NEVER mutate environment variables in tests.
- Integration tests MUST use a real Postgres instance via `testcontainers-python`. NEVER mock SQLAlchemy queries.
- MUST achieve 100% coverage across `src/app/routers/` and `src/app/services/` via `pytest-cov`. Exclude `main.py` and `db/migrations/`.
