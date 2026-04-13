# Usage

## 1. Apply the spec to your project

Reference `spec/index.md` when scaffolding or pass it directly to an agent:

```bash
claude -p "Read harnesses/go-api-blueprint/spec/index.md and scaffold a new Go API for [your domain]"
```

## 2. Bootstrap a new project

The spec expects this directory layout. Create it before implementing:

```
cmd/api/main.go
internal/app/app.go
internal/server/server.go
internal/config/config.go
internal/handler/
internal/middleware/
internal/service/
internal/model/
internal/db/
  schema.sql
  queries/
  migrations/
```

## 3. Required tooling

Install before running codegen or migrations:

```bash
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
go install github.com/pressly/goose/v3/cmd/goose@latest
go install github.com/swaggo/swag/cmd/swag@latest
```

## 4. Codegen workflow

After editing `.sql` query files, regenerate Go code:

```bash
sqlc generate
```

After editing handler or model annotations, regenerate OpenAPI docs:

```bash
swag init -g cmd/api/main.go
```

## 5. Running migrations

```bash
goose -dir internal/db/migrations postgres "$DATABASE_URL" up
```

## 6. Running tests

```bash
go test ./internal/... -cover -coverprofile=coverage.out
go tool cover -func=coverage.out
```

Integration tests require a running Postgres instance:

```bash
docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=test postgres:16
```
