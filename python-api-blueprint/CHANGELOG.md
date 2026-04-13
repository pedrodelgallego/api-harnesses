# Changelog

## 0.1.0

- Initial release.
- Stack: Python 3.12+, FastAPI, Pydantic v2, Pydantic Settings, SQLAlchemy 2.0 async Core, asyncpg, PyJWT, structlog, Alembic, slowapi, opentelemetry-sdk + opentelemetry-instrumentation-fastapi + opentelemetry-instrumentation-sqlalchemy, pytest + httpx + testcontainers, pytest-cov, uv.
- Violations table: 12 violations (all ERROR) covering routes without `response_model`, Pydantic models with `extra="allow"`, wildcard CORS on authenticated routes, JWT decoded without explicit `algorithms=`, `os.getenv()` in routers or services, blocking SQLAlchemy call in async route, Pydantic validation errors returned verbatim, `dict`/`Any` as route parameter or return type, `model.model_dump()` as substitute for `response_model` serialization, real `uvicorn` server in tests, DB mocked in integration tests, and `get_settings()` called directly in tests instead of via `dependency_overrides`.
- Sections: Stack, Project Structure, Security, Middleware Registration Order, Routes, Validation & Serialization, Logging, Lifecycle & Resilience, Telemetry, Configuration, Database, OpenAPI Documentation, Testing.
