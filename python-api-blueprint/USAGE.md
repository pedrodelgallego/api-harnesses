# Usage

## 1. Apply the spec to your project

Reference `spec/index.md` when scaffolding or pass it directly to an agent:

```bash
claude -p "Read harnesses/python-api-blueprint/spec/index.md and scaffold a new Python API for [your domain]"
```

## 2. Bootstrap a new project

```bash
uv init my-api && cd my-api
uv add fastapi "uvicorn[standard]" pydantic pydantic-settings sqlalchemy asyncpg \
    PyJWT structlog slowapi alembic opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc opentelemetry-instrumentation-fastapi \
    opentelemetry-instrumentation-sqlalchemy httpx
uv add --dev pytest pytest-asyncio pytest-cov testcontainers
```

The spec expects this layout:

```
src/app/
  main.py
  app.py
  config.py
  dependencies.py
  routers/
  middleware/
  services/
  models/
  db/
    engine.py
    tables.py
    queries/
    migrations/
pyproject.toml
alembic.ini
```

## 3. Required tooling

Install Alembic CLI for migration management:

```bash
uv run alembic init src/app/db/migrations
```

## 4. Running migrations

```bash
uv run alembic upgrade head
```

## 5. Running tests

```bash
uv run pytest --cov=src/app --cov-report=term-missing
```

Integration tests spin up a Postgres container automatically via `testcontainers`. A Docker daemon must be running.

## 6. Coverage

```bash
uv run pytest --cov=src/app --cov-fail-under=100 --cov-report=html
open htmlcov/index.html
```

The spec requires 100% coverage on `src/app/routers/` and `src/app/services/`. `main.py` and `db/migrations/` are excluded.
