# Usage

## 1. Apply the spec to your project

Reference `spec/index.md` when scaffolding or pass it directly to an agent:

```bash
claude -p "Read harnesses/kotlin-api-blueprint/spec/index.md and scaffold a new Ktor API for [your domain]"
```

## 2. Bootstrap a new project

Use the [Ktor project generator](https://start.ktor.io) or create a Gradle project manually. The spec expects this layout:

```
src/
  main/
    kotlin/com/example/
      Application.kt
      app/App.kt
      config/Config.kt
      routes/
      plugins/
      service/
      model/
      db/
        tables/
    resources/
      db/migration/
      logback.xml
  test/
    kotlin/com/example/
    resources/
      logback-test.xml
build.gradle.kts
```

## 3. Required tooling

No external CLI tools are required — Flyway runs automatically at startup via the Flyway Kotlin API. Ensure the following Gradle plugins are applied:

```kotlin
plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
    id("org.jetbrains.kotlinx.kover")
}
```

## 4. Running migrations

Migrations run automatically on startup via:

```kotlin
Flyway.configure()
    .dataSource(config.databaseUrl, config.dbUser, config.dbPassword)
    .load()
    .migrate()
```

To run migrations manually against a local database:

```bash
./gradlew flywayMigrate
```

## 5. Running tests

```bash
./gradlew test
```

Integration tests require a running Postgres instance (or use testcontainers-kotlin for automatic provisioning):

```bash
docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=test postgres:16
```

## 6. Coverage

```bash
./gradlew koverHtmlReport
```

Open `build/reports/kover/html/index.html` to view the coverage report. The spec requires 100% on `routes/` and `service/`.
