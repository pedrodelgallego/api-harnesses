# Kotlin API Blueprint

## Stack
- MUST use Kotlin (latest stable) on JVM 21 LTS.
- MUST use Kotlin coroutines. NEVER use blocking IO on coroutine threads.
- MUST use Gradle with Kotlin DSL (`build.gradle.kts`). NEVER Maven.
- MUST use Ktor. NEVER Spring Boot, NEVER http4k, NEVER Quarkus.
- MUST use `kotlinx-serialization`. NEVER Jackson, NEVER Gson.
- MUST use Konform. NEVER Hibernate Validator, NEVER `javax.validation` annotations.
- MUST use Exposed DSL. NEVER Hibernate/JPA, NEVER raw JDBC string queries.
- MUST use `com.auth0:java-jwt` for JWT validation only. NEVER issue tokens from app code; use an IDaaS provider.
- MUST use SLF4J + Logback + `logstash-logback-encoder`. NEVER `println`, NEVER Log4j directly.
- MUST use Hoplite. NEVER `System.getenv()` scattered across modules.
- MUST use Ktor `testApplication`. NEVER a real listening server in tests.
- MUST use Flyway. NEVER hand-applied SQL, NEVER Liquibase.

## Project Structure

MUST follow this layout exactly:

- `src/main/kotlin/.../Application.kt` — Calls `embeddedServer(...).start()`. ONLY entry point that binds a port.
- `src/main/kotlin/.../app/App.kt` — Configures and returns the `Application` module. NO engine start.
- `src/main/kotlin/.../config/Config.kt` — Hoplite config data class; loaded and validated at startup.
- `src/main/kotlin/.../routes/` — One file per resource; installs routes via `Routing` extension functions.
- `src/main/kotlin/.../plugins/` — Ktor plugin installation functions (one per concern).
- `src/main/kotlin/.../service/` — Business logic. Handlers NEVER contain business logic.
- `src/main/kotlin/.../model/` — Request/response data classes with `@Serializable` and Konform validators.
- `src/main/kotlin/.../db/` — Exposed table objects, database setup, transaction helpers.
- `src/main/resources/db/migration/` — Flyway migration files (`V{n}__{description}.sql`).

## Security

Implements [api-security harness](../../api-security/harness/index.md) and [api-security-headers harness](../../api-security-headers/harness/index.md).

Kotlin-specific implementation:

- Install `CORS` plugin with an explicit `allowHost` list from config. NEVER use `anyHost()` on authenticated routes.
- Install `SecureHeaders` plugin for security headers (X-Content-Type-Options, X-Frame-Options, etc.).
- Rate limit with Ktor's built-in `RateLimit` plugin (Ktor 2.3+); back with Redis for multi-instance deployments.
- Verify JWT via Ktor's `Authentication` plugin with the `jwt` provider; access claims via `call.principal<JWTPrincipal>()`. NEVER read `Authorization` headers manually. NEVER access JWT claims from `call.principal` without null-safe handling.
- NEVER ship a route handler that receives an unvalidated request body.
- NEVER return raw exception messages in a JSON response body.
- NEVER make blocking IO calls (`runBlocking`, `Thread.sleep`) inside a route handler.

## Plugin Installation Order

MUST install plugins in this order in `App.kt`:

1. `ContentNegotiation` (kotlinx-serialization JSON)
2. `CallLogging`
3. Correlation ID (custom plugin — see Logging)
4. `StatusPages` (error handling)
5. `CORS`
6. `SecureHeaders`
7. `RateLimit`
8. `Authentication`
9. Route installation

Protected route groups MUST wrap routes in `authenticate("jwt") { ... }`. NEVER inline auth checks inside handlers.

## Routes

Implements [api-versioning harness](../../api-versioning/harness/index.md). MUST prefix all routes with `/v1` from day one:

```kotlin
fun Application.configureRouting(userService: UserService) {
    routing {
        route("/v1") {
            userRoutes(userService)
        }
    }
}
```

MUST define a dedicated request data class and response data class for every route in `model/`. MUST call `validate(request)` immediately after deserializing. NEVER use request fields before validation.

MUST set a body size limit on every route that accepts a body:

```kotlin
const val MAX_BODY_BYTES = 1_048_576L // 1 MB
install(DoubleReceive)
// enforce per route via ContentLength check or custom plugin
```

NEVER put business logic in route handlers — delegate to a service function.

## Validation & Serialization

All request data classes MUST be validated with a Konform `Validation<T>` defined alongside the model. NEVER validate inside service functions. All response data classes MUST carry `@Serializable`.

- NEVER access request fields in a route handler without a prior `validate()` call.
- NEVER ship a response data class missing `@Serializable`.
- NEVER return validation errors verbatim — internal field names MUST NOT be exposed to the client.
- NEVER use `Any` or `Map<String, Any>` as a request or response type.

### Konform Validators

MUST define one `Validation<T>` per request model in the same file as the model:

```kotlin
val validateCreateUserRequest = Validation<CreateUserRequest> {
    CreateUserRequest::email { isEmail() }
    CreateUserRequest::name { minLength(1); maxLength(100) }
}
```

MUST call `validateCreateUserRequest(request)` in the handler and map `Invalid` to a `ValidationException`. NEVER let `ValidationResult` reach the route level unhandled.

### Error Formatting

MUST define a single `AppError` sealed class and handle all variants in the `StatusPages` plugin. NEVER return `HttpStatusCode` alone — always include a structured body.

```kotlin
@Serializable
data class ErrorBody(val errors: List<FieldError>)

@Serializable
data class FieldError(val field: String, val message: String)
```

NEVER expose Kotlin class names, stack traces, or raw Konform error keys to clients.

## Logging

Implements [api-logging harness](../../api-logging/harness/index.md). Kotlin-specific setup:

MUST use SLF4J API exclusively in application code (`LoggerFactory.getLogger(...)`). NEVER call `println`, `System.out`, or `System.err` in application code.

MUST configure Logback via `logback.xml`:

- In production: `LogstashEncoder` for structured JSON output
- In development: `PatternLayoutEncoder` with a human-readable pattern
- In tests: route all output to `/dev/null` via a `NullAppender`

MUST set log level from `LOG_LEVEL` env var; default `INFO` in production, `DEBUG` in development.

MUST propagate or generate a correlation ID in a custom Ktor plugin and store it in MDC:

```kotlin
val CorrelationId = createApplicationPlugin("CorrelationId") {
    onCall { call ->
        val id = call.request.headers["X-Correlation-ID"] ?: UUID.randomUUID().toString()
        MDC.put("correlationId", id)
        call.response.headers.append("X-Correlation-ID", id)
    }
}
```

MUST include `correlationId` and `service` in every structured log entry via MDC. MUST clear MDC after each call.

MUST redact `Authorization`, `Cookie`, `password`, `token`, and `secret` fields. NEVER log them verbatim. Configure redaction in `logback.xml` or via a custom `CallLogging` filter.

## Lifecycle & Resilience

Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md). Kotlin-specific implementation:

**Shutdown:**

MUST register a JVM shutdown hook that calls `server.stop(gracePeriodMillis, timeoutMillis)`:

```kotlin
val server = embeddedServer(Netty, port = config.port) { module() }
Runtime.getRuntime().addShutdownHook(Thread {
    server.stop(
        gracePeriodMillis = config.drainTimeoutMs / 2,
        timeoutMillis = config.drainTimeoutMs
    )
})
server.start(wait = true)
```

MUST read `DRAIN_TIMEOUT_MS` env var (default 10 000 ms) from config. NEVER hardcode the timeout.

NEVER call `System.exit()` directly — let the shutdown hook complete cleanly.

**Health & Readiness:**

MUST expose `GET /healthz` and `GET /readyz`. MUST skip auth, rate limiting, and access logging on both. Mount them outside the `/v1` prefix and outside the `authenticate` block.

**DB Pool:**

MUST configure HikariCP with `maximumPoolSize = (2 * Runtime.getRuntime().availableProcessors()) + 1`. MUST set `connectionTimeout = 2000` ms — return `503` immediately on pool exhaustion. NEVER queue indefinitely.

## Telemetry

Implements [api-telemetry harness](../../api-telemetry/harness/index.md). Kotlin-specific setup:

MUST use `opentelemetry-java` + `opentelemetry-kotlin` with the OTLP exporter.

MUST initialize the `OpenTelemetry` SDK in `Application.kt` before starting the server. MUST call `sdk.shutdown()` in the shutdown hook before the server stops.

MUST instrument Ktor with `io.opentelemetry.instrumentation:opentelemetry-ktor-2.0` for automatic HTTP span creation.

MUST skip tracing on `/healthz` and `/readyz`.

## Configuration

MUST load all config from environment variables using Hoplite:

```kotlin
data class AppConfig(
    val port: Int,
    val databaseUrl: String,
    val jwtSecret: String,
    val allowedOrigins: List<String>,
    val logLevel: String = "INFO",
    val drainTimeoutMs: Long = 10_000,
    val env: String = "production"
)

val config = ConfigLoaderBuilder.default()
    .addSource(EnvironmentVariablesConfigSource())
    .build()
    .loadConfigOrThrow<AppConfig>()
```

MUST hard-fail on startup if any required field is missing — Hoplite throws on `loadConfigOrThrow`.

NEVER use `System.getenv()` inside route handlers, services, or plugins. MUST pass `AppConfig` via constructor injection. NEVER use global singletons for config.

MUST accept `AppConfig` as a parameter in `fun Application.module(config: AppConfig)`. This enables per-test config injection without mutating the environment.

NEVER use `.env` files in production — use secrets manager injection.

## Database

MUST define all table schemas as Exposed `Table` objects in `src/main/kotlin/.../db/tables/`. MUST run Flyway migrations on startup before accepting requests:

```kotlin
Flyway.configure()
    .dataSource(config.databaseUrl, config.dbUser, config.dbPassword)
    .load()
    .migrate()
```

MUST use Exposed's DSL (`select`, `insert`, `update`, `deleteWhere`). NEVER use the DAO layer, NEVER call `exec()` with interpolated user input.

MUST wrap every multi-step operation in `transaction { ... }`. NEVER leave partial writes on failure.

MUST use `newSuspendedTransaction(Dispatchers.IO) { ... }` for all database calls from coroutine contexts. NEVER call `transaction { }` (blocking) from a route handler.

## OpenAPI Documentation

MUST use `io.github.smiley4:ktor-swagger-ui` for code-first OpenAPI generation.

MUST annotate every route with `get<Unit>({ ... }) { }` / `post<RequestType>({ ... }) { }` DSL describing summary, description, tags, request, and response types.

MUST install the `SwaggerUI` plugin in `App.kt` — after security plugins, before route installation.

MUST disable Swagger UI in production (guard with `config.env != "production"`) or protect it with authentication. NEVER expose API docs publicly in production.

MUST add `securitySchemeName("bearerAuth")` to all protected route documentation blocks.

## Testing

Implements [api-testing harness](../../api-testing/harness/index.md). Kotlin-specific rules:

- NEVER test a route handler with a real `embeddedServer(...).start()` call. MUST use Ktor's `testApplication`.
- NEVER mock the DB in integration tests. MUST use a real Postgres instance.
- NEVER call `System.getenv()` inside a test. MUST inject config via `module(config)`.
- NEVER wrap an entire test in blocking `runBlocking` when `runTest` can be used instead.

MUST use Ktor's `testApplication` for all route tests — no real port binding:

```kotlin
@Test
fun `create user returns 201`() = testApplication {
    application { module(testConfig()) }
    val response = client.post("/v1/users") {
        contentType(ContentType.Application.Json)
        setBody("""{"email":"a@b.com","name":"Alice"}""")
    }
    assertEquals(HttpStatusCode.Created, response.status)
}
```

MUST pass a test-specific `AppConfig` into `module(config)`. NEVER rely on environment variables in tests.

MUST configure Logback to discard all output during tests (`NullAppender` in `logback-test.xml`).

MUST run integration tests against a real Postgres instance (`testcontainers-kotlin`). NEVER mock Exposed queries for integration tests.

MUST reset database state between tests — truncate tables in `@BeforeEach` or use a transaction that rolls back after each test.

MUST achieve 100% coverage on lines, branches, and functions across `routes/` and `service/` packages. Exclude `Application.kt` and `db/tables/` from coverage requirements. Configure with Kover (`org.jetbrains.kotlinx.kover` Gradle plugin).
