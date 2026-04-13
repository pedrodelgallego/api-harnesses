# Usage

## 1. Apply the spec to your project

Reference `spec/index.md` when scaffolding or pass it directly to an agent:

```bash
claude -p "Read harnesses/rust-api-blueprint/spec/index.md and scaffold a new Rust API for [your domain]"
```

## 2. Bootstrap a new project

```bash
cargo new my-api && cd my-api
```

The spec expects this module layout under `src/`:

```
src/
  main.rs
  app.rs
  server.rs
  config.rs
  error.rs
  routes/
  middleware/
  service/
  model/
  db/
    migrations/
    queries/
```

## 3. Required tooling

Install before running codegen or migrations:

```bash
cargo install sqlx-cli --no-default-features --features rustls,postgres
```

## 4. Database setup

Create the database and run migrations:

```bash
sqlx database create
sqlx migrate run
```

After adding or editing query files, prepare the offline metadata for compile-time checking:

```bash
cargo sqlx prepare
```

Commit the generated `.sqlx/` directory — CI must not require a live database to compile.

## 5. Running tests

```bash
cargo test
```

Integration tests require a running Postgres instance:

```bash
docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=test postgres:16
```

Or use the `testcontainers` crate (configured in the spec) to spin one up automatically per test run.

## 6. Coverage

```bash
cargo install cargo-tarpaulin
cargo tarpaulin --out Html --exclude-files "src/main.rs"
```
