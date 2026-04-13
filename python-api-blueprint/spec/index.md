# Python API Blueprint

## Stack
- MUST use Python 3.12+.
- MUST use FastAPI. NEVER Django REST Framework. NEVER Flask.
- MUST use Pydantic v2 for validation and serialization. NEVER Marshmallow. NEVER Cerberus.
- MUST use Pydantic Settings (`pydantic-settings`) for config. NEVER `os.environ` / `os.getenv` scattered across modules.
- MUST use SQLAlchemy 2.0 async Core for the query layer. NEVER ORM mapped classes. NEVER raw string queries.
- MUST use `asyncpg` as the DB driver. NEVER `psycopg2` (blocking).
- MUST use `PyJWT` for JWT validation only. NEVER issue tokens from app code; use an IDaaS provider.
- MUST use `structlog` for logging. NEVER `print`. NEVER stdlib `logging.basicConfig` directly.
- MUST use Alembic for migrations. NEVER hand-applied SQL.
- MUST use `pytest` + `httpx.AsyncClient` via `ASGITransport` for testing. NEVER a real listening server in tests.
- MUST use `slowapi` backed by Redis for rate limiting. NEVER in-memory rate limiting in multi-instance deployments.
- MUST use `uv` as the package manager. NEVER `pip` directly in CI or developer scripts.

## Project Structure

MUST follow this layout exactly:

- `src/app/main.py` — Calls `uvicorn.run()`. ONLY entry point that binds a port.
- `src/app/app.py` — `create_app()` factory. Returns a `FastAPI` instance. NO `uvicorn.run()`.
- `src/app/config.py` — Pydantic `Settings` class; loaded once via `lru_cache`.
- `src/app/routers/` — One file per resource; returns an `APIRouter` mounted in `app.py`.
- `src/app/middleware/` — Starlette middleware classes (correlation ID, security headers, body size).
- `src/app/services/` — Business logic. Routers NEVER contain business logic.
- `src/app/models/` — Pydantic request and response models.
- `src/app/db/` — SQLAlchemy async engine, session factory, `queries/` subdirectory.
- `src/app/db/queries/` — SQLAlchemy Core query functions. One file per resource.
- `src/app/db/migrations/` — Alembic migration files.
- `src/app/dependencies.py` — FastAPI `Depends()` callables (auth, settings, db session).

## Security

Implements [api-security harness](../../api-security/harness/index.md) and [api-security-headers harness](../../api-security-headers/harness/index.md).

Python-specific implementation:

- Add `CORSMiddleware` with an explicit `allow_origins` list from `Settings` — NEVER `["*"]`. NEVER use `CORSMiddleware(allow_origins=["*"])` on authenticated routes.
- Add a custom `SecurityHeadersMiddleware` for HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`, and `Referrer-Policy`; strip `Server` header.
- Add `slowapi` `Limiter` globally; apply `@limiter.limit(...)` per-route where overrides are needed; back with Redis.
- Validate JWT in a `get_current_user` dependency via `Depends()`; store decoded claims as a typed `TokenData` dataclass — NEVER a raw `dict`. NEVER decode JWT without explicitly passing `algorithms=`.
- Every route MUST declare a `response_model`. NEVER ship a route without one.
- NEVER use `model_config = ConfigDict(extra="allow")` on Pydantic models.
- NEVER call `os.getenv()` inside a router, service, or dependency.
- NEVER make a blocking SQLAlchemy call (`session.execute` without `await`) in an async route.

## Middleware Registration Order

MUST add middleware in this order in `create_app()` (Starlette applies middleware bottom-up, so add in reverse priority order):

1. `BodySizeLimitMiddleware` (innermost — applied last)
2. Rate limiter (`SlowAPIMiddleware`)
3. Security headers (`SecurityHeadersMiddleware`)
4. `CORSMiddleware`
5. Correlation ID (`CorrelationIdMiddleware`) (outermost — applied first)

Protected routers MUST use `dependencies=[Depends(get_current_user)]` at the router level — NEVER inline auth checks inside route functions.

## Routes

Implements [api-versioning harness](../../api-versioning/harness/index.md). MUST prefix all routes with `/v1` from day one:

```python
app.include_router(users_router, prefix="/v1")
```

MUST declare `response_model` on every route — FastAPI uses it to serialize and filter the response, equivalent to TypeBox response schemas in the Fastify blueprint:

```python
@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(body: CreateUserRequest, ...): ...
```

MUST set `response_model_exclude_none=True` globally in `FastAPI()` constructor to prevent `null` fields leaking into responses.

MUST enforce a body size limit globally via `BodySizeLimitMiddleware`:

```python
MAX_BODY_BYTES = 1_048_576  # 1 MB — defined as a module-level constant

class BodySizeLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > MAX_BODY_BYTES:
            return JSONResponse({"detail": "Payload too large"}, status_code=413)
        return await call_next(request)
```

NEVER put business logic in route functions — delegate to a service function.

## Validation & Serialization

All request models MUST inherit from `BaseModel` and set `model_config = ConfigDict(extra="forbid")`. All response models MUST inherit from `BaseModel` and set `model_config = ConfigDict(extra="ignore")`.

- NEVER use `extra="allow"` or omit `extra` on a request model.
- NEVER ship a route without `response_model`.
- NEVER return validation error detail verbatim to the client (Pydantic field paths must not be exposed).
- NEVER use `dict` or `Any` as a route function parameter or return type.
- NEVER use `model.model_dump()` in place of `response_model` serialization.

### Pydantic Configuration

MUST configure all request models with `extra="forbid"` — rejects unknown fields, equivalent to `removeAdditional: true` in Fastify's AJV config.

MUST use `model_config = ConfigDict(populate_by_name=True, use_enum_values=True)` on all models.

MUST use `Field(...)` with constraints (`min_length`, `max_length`, `ge`, `le`, `pattern`) — NEVER rely on type annotation alone for input bounds.

### Error Formatting

MUST override FastAPI's default `RequestValidationError` handler to return RFC 7807 Problem Details format — NEVER expose Pydantic's internal `loc` tuples or field paths to clients:

```python
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={
            "type": "https://example.com/errors/validation",
            "title": "Validation Error",
            "status": 422,
            "instance": str(request.url),
            "errors": [
                {"field": ".".join(str(loc) for loc in e["loc"][1:]), "message": e["msg"]}
                for e in exc.errors()
            ],
        },
    )
```

NEVER let Pydantic's default error format (`{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}`) reach clients.

## Logging

Implements [api-logging harness](../../api-logging/harness/index.md). Python-specific setup:

MUST configure `structlog` once at startup in `create_app()` — NEVER call `structlog.configure()` inside a request handler or service.

```python
def configure_logging(settings: Settings) -> None:
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.stdlib.add_logger_name,
    ]
    if settings.env == "test":
        processors = shared_processors + [structlog.processors.JSONRenderer()]
        wrapper_class = structlog.make_filtering_bound_logger(logging.CRITICAL)  # silence in tests
    elif settings.env == "development":
        processors = shared_processors + [structlog.dev.ConsoleRenderer()]
        wrapper_class = structlog.make_filtering_bound_logger(logging.DEBUG)
    else:
        processors = shared_processors + [structlog.processors.JSONRenderer()]
        wrapper_class = structlog.make_filtering_bound_logger(logging.INFO)

    structlog.configure(processors=processors, wrapper_class=wrapper_class)
```

MUST set log level from `LOG_LEVEL` env var via `Settings`. Default `INFO` in production, `DEBUG` in development, `CRITICAL` in tests.

MUST propagate or generate a correlation ID in `CorrelationIdMiddleware` using `structlog.contextvars`:

```python
class CorrelationIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(correlation_id=correlation_id, service=SERVICE_NAME)
        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id
        return response
```

MUST call `structlog.contextvars.clear_contextvars()` at the start of every request — NEVER leave context vars on a recycled async task.

MUST redact `Authorization`, `Cookie`, `password`, `token`, and `secret` fields — configure via a custom `structlog` processor that masks known sensitive keys before rendering.

## Lifecycle & Resilience

Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md). Python-specific implementation:

**Startup & Shutdown:**

MUST use FastAPI's `lifespan` context manager for all startup and shutdown logic — NEVER `@app.on_event("startup")`/`@app.on_event("shutdown")` (deprecated):

```python
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    init_telemetry(settings)
    await engine.connect()
    yield
    await engine.dispose()
    await shutdown_telemetry()

app = FastAPI(lifespan=lifespan)
```

MUST configure uvicorn graceful shutdown via `--timeout-graceful-shutdown` sourced from `DRAIN_TIMEOUT_MS` env var (default 10 s) — NEVER hardcode it.

**Health & Readiness:**

MUST expose `GET /healthz` and `GET /readyz`. MUST exclude both from auth, rate limiting, and OTel tracing. Mount them directly on `app` before including versioned routers.

**DB Pool:**

MUST configure pool size in `create_async_engine`:

```python
engine = create_async_engine(
    settings.database_url,
    pool_size=(2 * (os.cpu_count() or 1)) + 1,
    max_overflow=0,
    pool_timeout=2,  # return 503 on exhaustion, never queue indefinitely
    pool_pre_ping=True,
)
```

MUST return `503` immediately on pool exhaustion — catch `asyncio.TimeoutError` from `pool_timeout` and raise `HTTPException(503)`.

## Telemetry

Implements [api-telemetry harness](../../api-telemetry/harness/index.md). Python-specific setup:

MUST initialize the OTel SDK in the `lifespan` startup block — NEVER at module import time.

MUST call `FastAPIInstrumentor().instrument_app(app)` after `create_app()` returns and before `uvicorn.run()` in `main.py`.

MUST instrument SQLAlchemy with `SQLAlchemyInstrumentor().instrument(engine=engine)`.

MUST call `TracerProvider.shutdown()` and `MeterProvider.shutdown()` in the `lifespan` cleanup block.

MUST exclude `/healthz` and `/readyz` from tracing by passing `excluded_urls` to `FastAPIInstrumentor`.

## Configuration

MUST load all config from environment variables using Pydantic Settings:

```python
from functools import lru_cache
from pydantic import Field, PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    port: int
    database_url: PostgresDsn
    jwt_secret: str = Field(min_length=32)
    allowed_origins: list[str]
    log_level: str = "INFO"
    drain_timeout_ms: int = 10_000
    env: str = "production"

    model_config = SettingsConfigDict(env_file=None)  # never .env in production

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

MUST hard-fail on startup if any required field is missing — Pydantic Settings raises `ValidationError` on `Settings()`.

MUST inject `Settings` via `Depends(get_settings)` — NEVER call `get_settings()` inside route functions or services directly. This enables per-test override via `app.dependency_overrides`.

NEVER use `.env` files in production — use secrets manager injection.

## Database

MUST define all table schemas as SQLAlchemy `Table` objects in `src/app/db/tables.py`. MUST write all queries as explicit SQLAlchemy Core expressions in `src/app/db/queries/` — NEVER use ORM `Session` or mapped classes.

MUST manage all schema changes with Alembic. Migration files live in `src/app/db/migrations/`. MUST run `alembic upgrade head` at startup before serving requests (in the `lifespan` block).

MUST use parameterised queries exclusively — SQLAlchemy Core enforces this. NEVER use `text()` with f-strings or `.format()`.

MUST wrap multi-step operations in a transaction:

```python
async with engine.begin() as conn:
    await conn.execute(insert_stmt)
    await conn.execute(update_stmt)
    # commits on context exit, rolls back on exception
```

## OpenAPI Documentation

FastAPI generates OpenAPI automatically from type hints and `response_model` declarations — no separate annotation step required.

MUST add `summary`, `description`, and `tags` to every route decorator:

```python
@router.post(
    "/users",
    response_model=UserResponse,
    status_code=201,
    summary="Create a user",
    description="Creates a new user account. Requires authentication.",
    tags=["users"],
)
```

MUST disable docs in production by passing `docs_url=None, redoc_url=None` to `FastAPI()` when `settings.env == "production"`, or protect them with authentication. NEVER expose API docs publicly in production.

MUST declare `openapi_extra={"security": [{"bearerAuth": []}]}` on all protected routes.

## Testing

Implements [api-testing harness](../../api-testing/harness/index.md). Python-specific rules:

- NEVER test a route with a real `uvicorn` server.
- NEVER mock the DB in integration tests — MUST use a real Postgres instance.
- NEVER call `get_settings()` directly in tests — MUST override via `dependency_overrides`.
- NEVER call `asyncio.run()` inside a test function.

MUST use `httpx.AsyncClient` with `ASGITransport` for all route tests — no real server:

```python
@pytest.fixture
async def client(app: FastAPI) -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        yield client
```

MUST override `get_settings` via `app.dependency_overrides` in the test fixture — NEVER mutate environment variables in tests:

```python
app.dependency_overrides[get_settings] = lambda: Settings(
    database_url="postgresql+asyncpg://...", env="test", ...
)
```

MUST set `env="test"` in test settings so `structlog` discards all output — NEVER emit log output during test runs.

MUST run integration tests against a real Postgres instance via `pytest-docker` or `testcontainers-python` — NEVER mock SQLAlchemy queries for integration tests.

MUST reset database state between tests — truncate tables in a `pytest` fixture with `autouse=True` or use a transaction that rolls back after each test.

MUST achieve 100% coverage on lines, branches, and functions across `src/app/routers/` and `src/app/services/`. Exclude `src/app/main.py` and `src/app/db/migrations/` from coverage requirements. Configure with `pytest-cov`:

```toml
[tool.coverage.run]
source = ["src/app"]
omit = ["src/app/main.py", "src/app/db/migrations/*"]

[tool.coverage.report]
fail_under = 100
```
