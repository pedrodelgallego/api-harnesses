# Usage

## 1. Apply the spec to your project

Reference `spec/index.md` when scaffolding or pass it directly to an agent:

```bash
claude -p "Read harnesses/springboot-kotlin-api-blueprint/spec/index.md and scaffold a new Spring Boot API for [your domain]"
```

## 2. Bootstrap a new project

Use [start.spring.io](https://start.spring.io) with the following selections, then apply the spec layout:

- Language: Kotlin
- Build: Gradle - Kotlin
- Spring Boot: 3.x (latest)
- Dependencies: Spring Web, Spring Data JPA, Spring Security, Flyway, Validation, Actuator

The spec expects this layout:

```
src/
  main/
    kotlin/com/example/
      Application.kt
      config/
        SecurityConfig.kt
        OpenApiConfig.kt
        AppProperties.kt
      controller/
      service/
      repository/
      domain/
      dto/
        request/
        response/
      exception/
        GlobalExceptionHandler.kt
    resources/
      application.yml
      db/migration/
      logback-spring.xml
  test/
    kotlin/com/example/
    resources/
      logback-test.xml
build.gradle.kts
```

## 3. Required compiler plugins

MUST apply both in `build.gradle.kts` or the project will fail at runtime:

```kotlin
plugins {
    kotlin("plugin.spring")
    kotlin("plugin.jpa")
    id("org.jetbrains.kotlinx.kover")
}
```

## 4. Running migrations

Flyway runs automatically on startup. To run migrations manually:

```bash
./gradlew flywayMigrate
```

Migration files live in `src/main/resources/db/migration/` and follow `V{n}__{description}.sql`.

## 5. Running tests

```bash
./gradlew test
```

`@DataJpaTest` integration tests require Testcontainers — a Docker daemon must be running. No separate Postgres setup needed.

## 6. Coverage

```bash
./gradlew koverHtmlReport
```

Open `build/reports/kover/html/index.html`. The spec requires 100% on `controller/`, `service/`, and `repository/` packages.
