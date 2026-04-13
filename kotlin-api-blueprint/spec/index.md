# Kotlin API Blueprint

## Scope
This file maps the general `api-*` harnesses to concrete Ktor/Kotlin implementation rules. It MUST NOT redefine the general API contract.

## Stack
- MUST use Kotlin (latest stable) on JVM 21 LTS.
- MUST use Gradle with Kotlin DSL (`build.gradle.kts`). NEVER Maven.
- MUST use Ktor. NEVER Spring Boot, NEVER http4k, NEVER Quarkus.
- MUST use `kotlinx-serialization`. NEVER Jackson, NEVER Gson.
- MUST use Konform for validation. NEVER Hibernate Validator, NEVER `javax.validation` annotations.
- MUST use Exposed DSL. NEVER Hibernate/JPA, NEVER raw JDBC string queries.
- MUST use `newSuspendedTransaction(Dispatchers.IO)` for all DB calls from coroutines. NEVER blocking `transaction {}` from a route handler.
- MUST use `com.auth0:java-jwt` for JWT validation only. NEVER issue tokens from app code.
- MUST use SLF4J + Logback + `logstash-logback-encoder`. NEVER `println`, NEVER Log4j directly.
- MUST use Hoplite for config. NEVER `System.getenv()` scattered across modules.
- MUST use Ktor `testApplication` in tests. NEVER a real listening server.
- MUST use Flyway for migrations. NEVER hand-applied SQL.

## Project Structure
- `Application.kt` MUST be the only entry point that starts the server.
- `app/App.kt` MUST configure and return the `Application` module. MUST NOT start the engine.
- `config/Config.kt` — Hoplite config data class; loaded and validated at startup.
- `routes/` — one file per resource; installs routes via `Routing` extension functions.
- `plugins/` — Ktor plugin installation functions, one per concern.
- `service/` — business logic. Handlers MUST NOT contain business logic.
- `model/` — request/response data classes with `@Serializable` and Konform validators.
- `db/` — Exposed table objects, database setup, transaction helpers.
- `src/main/resources/db/migration/` — Flyway migration files.

## Plugin Installation Order
MUST install plugins in this order in `App.kt`:
1. `ContentNegotiation` (kotlinx-serialization JSON)
2. `CallLogging`
3. Correlation ID (custom plugin)
4. `StatusPages` (error handling)
5. `CORS`
6. `SecureHeaders`
7. `RateLimit`
8. `Authentication`
9. Route installation

Protected route groups MUST use `authenticate("jwt") { ... }`. NEVER inline auth checks inside handlers.

## Security
- MUST use the `CORS` plugin with an explicit `allowHost` list from config. NEVER `anyHost()`.
- MUST use the `SecureHeaders` plugin for security headers.
- MUST use the `RateLimit` plugin backed by Redis for multi-instance deployments.
- JWT MUST be verified via Ktor's `Authentication` plugin with the `jwt` provider. NEVER read `Authorization` headers manually.
- Route handlers MUST NOT perform blocking IO (`runBlocking`, `Thread.sleep`).

## Routes
- All routes MUST be prefixed with `/v1`.
- Every route MUST define a dedicated request data class and call `validate(request)` immediately after deserializing. NEVER access request fields before validation.
- Every route that accepts a body MUST set a body size limit.

## Validation and Serialization
- MUST define one `Validation<T>` per request model in the same file as the model.
- `Invalid` results MUST be mapped to a `ValidationException`. NEVER let `ValidationResult` reach the route level unhandled.
- MUST define a single `AppError` sealed class and handle all variants in the `StatusPages` plugin.
- NEVER expose Kotlin class names, stack traces, or raw Konform error keys to clients.

## Logging
- MUST use SLF4J API exclusively in application code. NEVER `println`, `System.out`, or `System.err`.
- In production MUST use `LogstashEncoder`; in development `PatternLayoutEncoder`; in tests `NullAppender` via `logback-test.xml`.
- MUST propagate or generate a correlation ID in a custom Ktor plugin and store it in MDC. MUST call `MDC.clear()` after each call.

## Resilience and Lifecycle
- MUST register a JVM shutdown hook that calls `server.stop(gracePeriodMillis, timeoutMillis)`.
- MUST read `DRAIN_TIMEOUT_MS` from config. NEVER hardcode the timeout. NEVER call `System.exit()` directly.
- HikariCP MUST be configured with `maximumPoolSize = (2 * availableProcessors) + 1` and `connectionTimeout = 2000` ms.

## Telemetry
- MUST use `opentelemetry-java` + `opentelemetry-kotlin` with the OTLP exporter.
- MUST instrument Ktor with `opentelemetry-ktor-2.0`.
- MUST initialize the SDK before starting the server. MUST call `sdk.shutdown()` in the shutdown hook.

## Configuration
- MUST use Hoplite with `EnvironmentVariablesConfigSource` and `loadConfigOrThrow`. Hard-fail on startup if any required field is missing.
- MUST accept `AppConfig` as a parameter in `fun Application.module(config: AppConfig)` to enable test config injection.
- NEVER use `System.getenv()` inside handlers, services, or plugins.

## Database
- MUST define all table schemas as Exposed `Table` objects in `db/tables/`.
- MUST run Flyway migrations on startup before accepting requests.
- MUST use Exposed's DSL (`select`, `insert`, `update`, `deleteWhere`). NEVER the DAO layer. NEVER `exec()` with interpolated input.
- MUST use `newSuspendedTransaction(Dispatchers.IO)` for all database calls from coroutine contexts.

## OpenAPI
- MUST use `io.github.smiley4:ktor-swagger-ui` for code-first OpenAPI generation.
- MUST annotate every route with summary, description, tags, request, and response types.
- Swagger UI MUST be disabled in production or protected by authentication.
- MUST add `securitySchemeName("bearerAuth")` to all protected route documentation blocks.

## Testing
- MUST use Ktor's `testApplication` for all route tests. NEVER a real port binding.
- MUST pass a test-specific `AppConfig` into `module(config)`. NEVER rely on environment variables in tests.
- MUST configure Logback with `NullAppender` in `logback-test.xml`.
- Integration tests MUST use a real Postgres instance via `testcontainers-kotlin`. NEVER mock Exposed queries.
- MUST achieve 100% coverage across `routes/` and `service/` via Kover. Exclude `Application.kt` and `db/tables/`.
