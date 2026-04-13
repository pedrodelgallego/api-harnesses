# Spring Boot Kotlin API Blueprint

## Stack
- MUST use Kotlin (latest stable) on JVM 21 LTS.
- MUST use Gradle with Kotlin DSL (`build.gradle.kts`). NEVER Maven.
- MUST use Spring Boot 3.x with Spring MVC. NEVER WebFlux unless explicitly justified.
- MUST use Jackson with `jackson-module-kotlin` for serialization. NEVER Gson.
- MUST use Bean Validation (`jakarta.validation`) via `@Valid`. NEVER Konform, NEVER manual checks.
- MUST use Spring Data JPA + Hibernate for ORM — entities MUST follow the rules below.
- MUST use Spring Security OAuth2 Resource Server (JWT decoder) for auth. NEVER `com.auth0:java-jwt` manually, NEVER hand-roll JWT parsing.
- MUST use SLF4J + Logback + `logstash-logback-encoder` for logging. NEVER `println`, NEVER Log4j directly.
- MUST use `@ConfigurationProperties` with Kotlin data classes for config. NEVER `@Value` for structured config.
- MUST use `@SpringBootTest(webEnvironment = MOCK)` + `MockMvc` for testing. NEVER a real listening server in unit or integration tests.
- MUST use Flyway for migrations. NEVER hand-applied SQL, NEVER Liquibase.

## Compiler Plugins

MUST apply both Kotlin compiler plugins in `build.gradle.kts` — without them, Hibernate proxy generation and JPA no-arg constructors fail silently at runtime:

```kotlin
plugins {
    kotlin("plugin.spring")  // makes @Component/@Entity/@Transactional classes open
    kotlin("plugin.jpa")     // generates no-arg constructors for @Entity, @Embeddable, @MappedSuperclass
}
```

NEVER manually add `open` to entity or component classes — let the plugins handle it.

## Project Structure

MUST follow this layout exactly:

- `src/main/kotlin/.../Application.kt` — `@SpringBootApplication` + `main()`. ONLY entry point.
- `src/main/kotlin/.../config/` — Spring configuration classes (`SecurityConfig`, `OpenApiConfig`, `AppProperties`).
- `src/main/kotlin/.../controller/` — `@RestController` — one file per resource.
- `src/main/kotlin/.../service/` — `@Service` — all business logic lives here.
- `src/main/kotlin/.../repository/` — `JpaRepository` interfaces. NEVER add business logic here.
- `src/main/kotlin/.../domain/` — JPA `@Entity` classes.
- `src/main/kotlin/.../dto/request/` — Validated request DTOs.
- `src/main/kotlin/.../dto/response/` — Response DTOs. NEVER expose entities directly.
- `src/main/kotlin/.../exception/` — `@RestControllerAdvice` global error handler.
- `src/main/resources/db/migration/` — Flyway migration files (`V{n}__{description}.sql`).

## Security

Implements [api-security harness](../../api-security/harness/index.md) and [api-security-headers harness](../../api-security-headers/harness/index.md).

Spring-specific violations:

- MUST NEVER return a JPA entity directly from a `@RestController` method.
- MUST NEVER use `@RequestBody` without `@Valid`.
- MUST NEVER configure CORS with `allowedOrigins("*")` on authenticated routes.
- MUST NEVER apply `permitAll()` to any route outside of `/healthz`, `/readyz`, `/v1/auth/**`, and Swagger UI.
- MUST NEVER use `http.csrf { it.disable() }` without a comment explaining why it is safe (stateless JWT).

Spring-specific implementation:

- Configure CORS in `SecurityConfig` with an explicit `allowedOrigins` list from `AppProperties` — NEVER use `@CrossOrigin` on controllers.
- Configure security headers via `http.headers { ... }` in `SecurityConfig`.
- Rate limit with `bucket4j-spring-boot-starter` backed by Redis for multi-instance deployments.
- Configure JWT resource server via `http.oauth2ResourceServer { jwt { ... } }` — NEVER parse `Authorization` headers manually in controllers or services.

## Spring Security Configuration Order

MUST configure `SecurityFilterChain` in this order in `SecurityConfig`:

1. `csrf` (disable — stateless JWT, document why)
2. `cors`
3. `headers`
4. `sessionManagement` (`STATELESS`)
5. `authorizeHttpRequests` (deny-by-default: `anyRequest().authenticated()`)
6. `oauth2ResourceServer` (JWT decoder)
7. Rate limiting filter

NEVER use `@PreAuthorize` or `@Secured` as the sole auth mechanism — always pair with `authorizeHttpRequests` deny-by-default.

## Routes

Implements [api-versioning harness](../../api-versioning/harness/index.md). MUST prefix all routes with `/v1` from day one via `@RequestMapping("/v1/resource")` on each controller class.

MUST annotate every `@RequestBody` parameter with `@Valid` — NEVER rely on manual validation inside service methods for HTTP input.

MUST set a maximum request body size in `application.yml`:

```yaml
spring:
  servlet:
    multipart:
      max-request-size: 1MB
      max-file-size: 1MB
server:
  tomcat:
    max-http-request-header-size: 8KB
```

NEVER put business logic in controllers — delegate entirely to a service function.

## Validation & Serialization

All request DTOs MUST use Bean Validation annotations (`@NotBlank`, `@Size`, `@Email`, `@NotNull`, etc.). All response DTOs MUST be plain Kotlin data classes with no JPA annotations.

- MUST NEVER use `@RequestBody` without `@Valid` in the controller method signature.
- MUST NEVER include a JPA `@Entity` reference in a response DTO.
- MUST NEVER expose internal field paths or class names in validation error messages.
- MUST NEVER use `Any` or `Map<String, Any>` as a controller method parameter or return type.
- MUST NEVER use `@JsonIgnore` on an entity field as a substitute for a proper response DTO.

### Jackson Configuration

MUST configure Jackson in `application.yml`:

```yaml
spring:
  jackson:
    default-property-inclusion: non_null
    deserialization:
      fail-on-unknown-properties: true
    serialization:
      write-dates-as-timestamps: false
```

`fail-on-unknown-properties: true` mirrors `removeAdditional` in the Fastify blueprint — unknown fields are rejected, not silently ignored.

### Error Formatting

MUST handle all exceptions in a single `@RestControllerAdvice` class. NEVER let Spring's default `DefaultHandlerExceptionResolver` error format reach clients — it exposes internal class names.

```kotlin
@Serializable
data class ErrorBody(val errors: List<FieldError>)

data class FieldError(val field: String, val message: String)
```

MUST map `MethodArgumentNotValidException` to `400` with the normalized `ErrorBody`. NEVER expose stack traces, Hibernate exception messages, or constraint names to clients.

## JPA Entities

JPA entities have specific rules to avoid Hibernate pitfalls with Kotlin:

- MUST NEVER declare an `@Entity` class as a `data class`.
- MUST NEVER use `FetchType.EAGER` on any `@OneToMany` or `@ManyToMany` association.
- MUST NEVER expose an entity directly in a controller response.
- MUST NEVER access a lazy association outside an active transaction.
- MUST NEVER enable `spring.jpa.open-in-view=true` (OSIV).

MUST declare entity classes as regular `class`, not `data class` — `data class` equality semantics conflict with Hibernate proxy identity:

```kotlin
@Entity
@Table(name = "users")
class User(
    @Column(nullable = false)
    val email: String,

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0
)
```

MUST default all associations to `FetchType.LAZY`. MUST use `@EntityGraph` or JPQL `JOIN FETCH` to load associations eagerly when needed — NEVER rely on OSIV to trigger lazy loads outside a transaction.

MUST disable OSIV in `application.yml`:
```yaml
spring:
  jpa:
    open-in-view: false
```

## Transactions

MUST annotate service methods with `@Transactional` — NEVER place `@Transactional` on controllers or repositories.

MUST use `@Transactional(readOnly = true)` on all read-only service methods — this prevents dirty-checking overhead and signals intent.

MUST never call a `@Transactional` method from within the same class (self-invocation bypasses the proxy) — extract to a separate service if needed.

## Logging

Implements [api-logging harness](../../api-logging/harness/index.md). Spring-specific setup:

MUST use SLF4J API exclusively (`LoggerFactory.getLogger(...)`). NEVER call `println`, `System.out`, or `System.err`.

MUST configure Logback via `logback-spring.xml` using Spring profiles:

- `production` profile: `LogstashEncoder` for structured JSON.
- `default`/`development` profile: `PatternLayoutEncoder` with human-readable format.
- `test` profile: `NullAppender` — discard all output during tests.

MUST set log level from `LOG_LEVEL` env var via `<springProperty>` in `logback-spring.xml`. Default `INFO` in production, `DEBUG` in development.

MUST propagate or generate a correlation ID in a `OncePerRequestFilter` and store it in MDC:

```kotlin
class CorrelationIdFilter : OncePerRequestFilter() {
    override fun doFilterInternal(request: HttpServletRequest, response: HttpServletResponse, chain: FilterChain) {
        val id = request.getHeader("X-Correlation-ID") ?: UUID.randomUUID().toString()
        MDC.put("correlationId", id)
        response.setHeader("X-Correlation-ID", id)
        try { chain.doFilter(request, response) } finally { MDC.clear() }
    }
}
```

MUST call `MDC.clear()` in a `finally` block — NEVER leave MDC state on a recycled thread-pool thread.

MUST redact `Authorization`, `Cookie`, `password`, `token`, and `secret` fields — NEVER log them verbatim.

## Lifecycle & Resilience

Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md). Spring-specific implementation:

**Shutdown:**

MUST enable graceful shutdown in `application.yml`:

```yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: ${DRAIN_TIMEOUT_MS:10000}ms
```

NEVER call `System.exit()` directly — Spring's `SmartLifecycle` handles drain and shutdown ordering.

**Health & Readiness:**

MUST expose Spring Actuator's `/healthz` (liveness) and `/readyz` (readiness) probes:

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
  endpoints:
    web:
      base-path: /
      path-mapping:
        health: healthz
```

MUST exclude Actuator endpoints from auth, rate limiting, and access logging.

**DB Pool:**

MUST configure HikariCP in `application.yml`:

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: # (2 * availableProcessors) + 1 — set explicitly, never rely on default 10
      connection-timeout: 2000
      keepalive-time: 30000
```

MUST set `connection-timeout: 2000` ms — return `503` immediately on pool exhaustion. NEVER queue indefinitely.

## Telemetry

Implements [api-telemetry harness](../../api-telemetry/harness/index.md). Spring-specific setup:

MUST use Spring Boot Actuator + Micrometer with the OTLP registry (`micrometer-registry-otlp`).

MUST auto-configure tracing via `spring-boot-starter-actuator` and `micrometer-tracing-bridge-otel` with the OTLP exporter.

MUST exclude `/healthz` and `/readyz` from tracing and metrics collection.

## Configuration

MUST load all config via a `@ConfigurationProperties` data class — NEVER use `@Value` for structured multi-field config:

```kotlin
@ConfigurationProperties(prefix = "app")
data class AppProperties(
    val jwtIssuerUri: String,
    val allowedOrigins: List<String>,
    val drainTimeoutMs: Long = 10_000,
    val env: String = "production"
)
```

MUST annotate the class with `@Validated` and field-level Bean Validation constraints so Spring fails fast on startup for missing required values.

MUST bind `AppProperties` via `@EnableConfigurationProperties(AppProperties::class)` in `Application.kt`.

NEVER scatter `@Value("${some.prop}")` across controllers or services — all config access flows through `AppProperties`.

NEVER commit secrets to `application.yml` — use environment variable overrides (`SPRING_DATASOURCE_URL`, etc.) or a secrets manager.

## Database

MUST manage all schema changes with Flyway. Migration files MUST live in `src/main/resources/db/migration/` and follow the naming convention `V{n}__{description}.sql`.

MUST enable Flyway validation on startup:
```yaml
spring:
  flyway:
    enabled: true
    validate-on-migrate: true
```

MUST use Spring Data JPA repository methods or `@Query` with JPQL/named parameters — NEVER construct JPQL or SQL strings with string interpolation or concatenation.

MUST wrap all multi-step data operations in a single `@Transactional` service method — NEVER leave partial writes on failure.

## OpenAPI Documentation

MUST use `springdoc-openapi-starter-webmvc-ui` (SpringDoc 2.x). NEVER use Springfox — it is unmaintained and incompatible with Spring Boot 3.

MUST configure SpringDoc in `OpenApiConfig`:

```kotlin
@Bean
fun openApi(): OpenAPI = OpenAPI()
    .info(Info().title("My API").version("v1"))
    .addSecurityItem(SecurityRequirement().addList("bearerAuth"))
    .components(Components().addSecuritySchemes("bearerAuth",
        SecurityScheme().type(HTTP).scheme("bearer").bearerFormat("JWT")))
```

MUST disable Swagger UI in production (guard with `springdoc.swagger-ui.enabled: false` via profile or `AppProperties.env`). NEVER expose API docs publicly in production.

MUST add `@Operation`, `@ApiResponse`, and `@Tag` annotations to every controller method.

## Testing

Implements [api-testing harness](../../api-testing/harness/index.md). Spring-specific violations:

- MUST NEVER use `@SpringBootTest(webEnvironment = RANDOM_PORT)` for controller tests.
- MUST NEVER mock the DB in `@DataJpaTest` — MUST use Testcontainers Postgres.
- MUST NEVER place `@Transactional` on a `@SpringBootTest` integration test (masks missing commit bugs).
- MUST NEVER return an entity directly from a controller under test.

MUST use `@SpringBootTest(webEnvironment = MOCK)` + `MockMvc` for controller integration tests — no real port binding:

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
class UserControllerTest(@Autowired val mockMvc: MockMvc) {
    @Test
    fun `create user returns 201`() {
        mockMvc.post("/v1/users") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"a@b.com","name":"Alice"}"""
        }.andExpect { status { isCreated() } }
    }
}
```

MUST use `@WebMvcTest(UserController::class)` for isolated controller slice tests — mock the service layer with `@MockkBean` (MockK) or `@MockBean`.

MUST use `@DataJpaTest` with Testcontainers Postgres for repository tests — NEVER use H2 as a Postgres substitute.

MUST configure Logback with a `NullAppender` in `logback-test.xml` — NEVER emit log output during test runs.

MUST reset database state between integration tests — truncate tables in `@BeforeEach` or use `@Sql` scripts.

MUST achieve 100% coverage on lines, branches, and functions across `controller/`, `service/`, and `repository/` packages. Exclude `Application.kt` and `domain/` from coverage requirements. Configure with Kover (`org.jetbrains.kotlinx.kover` Gradle plugin).
