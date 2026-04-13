# Spring Boot Kotlin API Blueprint

## Scope
This file maps the general `api-*` harnesses to concrete Spring Boot/Kotlin implementation rules. It MUST NOT redefine the general API contract.

## Stack
- MUST use Kotlin (latest stable) on JVM 21 LTS.
- MUST use Gradle with Kotlin DSL (`build.gradle.kts`). NEVER Maven.
- MUST use Spring Boot 3.x with Spring MVC. NEVER WebFlux unless explicitly justified.
- MUST use Jackson with `jackson-module-kotlin`. NEVER Gson.
- MUST use Bean Validation (`jakarta.validation`) via `@Valid`. NEVER Konform, NEVER manual checks.
- MUST use Spring Data JPA + Hibernate. NEVER raw JDBC for persistence.
- MUST use Spring Security OAuth2 Resource Server for JWT. NEVER hand-roll JWT parsing.
- MUST use SLF4J + Logback + `logstash-logback-encoder`. NEVER `println`, NEVER Log4j directly.
- MUST use `@ConfigurationProperties` for structured config. NEVER `@Value` for multi-field config.
- MUST use `@SpringBootTest(webEnvironment = MOCK)` + `MockMvc` in tests. NEVER `RANDOM_PORT`.
- MUST use Flyway for migrations. NEVER hand-applied SQL, NEVER Liquibase.
- MUST apply `kotlin("plugin.spring")` and `kotlin("plugin.jpa")` compiler plugins. NEVER add `open` modifiers manually.

## Project Structure
- `Application.kt` — `@SpringBootApplication` + `main()`. ONLY entry point.
- `config/` — Spring configuration classes (`SecurityConfig`, `OpenApiConfig`, `AppProperties`).
- `controller/` — `@RestController`, one file per resource.
- `service/` — `@Service`, all business logic lives here.
- `repository/` — `JpaRepository` interfaces. NEVER add business logic here.
- `domain/` — JPA `@Entity` classes.
- `dto/request/` — validated request DTOs.
- `dto/response/` — response DTOs. NEVER expose entities directly.
- `exception/` — `@RestControllerAdvice` global error handler.
- `src/main/resources/db/migration/` — Flyway migration files.

## Spring Security Configuration Order
MUST configure `SecurityFilterChain` in this order in `SecurityConfig`:
1. `csrf` (disable — stateless JWT; document why)
2. `cors`
3. `headers`
4. `sessionManagement` (`STATELESS`)
5. `authorizeHttpRequests` (deny-by-default: `anyRequest().authenticated()`)
6. `oauth2ResourceServer` (JWT decoder)
7. Rate limiting filter

NEVER use `@PreAuthorize` or `@Secured` as the sole auth mechanism — always pair with deny-by-default.

## Security
- CORS MUST be configured in `SecurityConfig` with an explicit `allowedOrigins` list from `AppProperties`. NEVER `@CrossOrigin` on controllers.
- Security headers MUST be configured via `http.headers { ... }` in `SecurityConfig`.
- MUST use `bucket4j-spring-boot-starter` backed by Redis for rate limiting.

## Routes
- All routes MUST be prefixed with `/v1` via `@RequestMapping("/v1/resource")` on each controller class.
- Every `@RequestBody` parameter MUST be annotated with `@Valid`. NEVER rely on manual validation in service methods.
- Maximum request body size MUST be set in `application.yml`.
- NEVER put business logic in controllers.

## Validation and Serialization
- All request DTOs MUST use Bean Validation annotations (`@NotBlank`, `@Size`, `@Email`, `@NotNull`).
- All response DTOs MUST be plain Kotlin data classes with no JPA annotations. NEVER expose entities directly.
- MUST handle all exceptions in a single `@RestControllerAdvice` class.
- Jackson MUST be configured with `fail-on-unknown-properties: true` and `default-property-inclusion: non_null`.

## JPA Entities
- MUST declare entity classes as regular `class`. NEVER `data class` — Hibernate proxy conflicts.
- MUST default all associations to `FetchType.LAZY`. NEVER `FetchType.EAGER` on `@OneToMany` or `@ManyToMany`.
- MUST disable OSIV: `spring.jpa.open-in-view=false`.
- NEVER access a lazy association outside an active transaction.

## Transactions
- MUST annotate service methods with `@Transactional`. NEVER on controllers or repositories.
- MUST use `@Transactional(readOnly = true)` on all read-only service methods.
- NEVER call a `@Transactional` method from within the same class (self-invocation bypasses the proxy).

## Logging
- MUST use SLF4J API exclusively. NEVER `println`, `System.out`, or `System.err`.
- In production MUST use `LogstashEncoder`; in development `PatternLayoutEncoder`; in tests `NullAppender` via `logback-test.xml`.
- MUST propagate or generate a correlation ID in a `OncePerRequestFilter` and store it in MDC. MUST call `MDC.clear()` in a `finally` block.

## Resilience and Lifecycle
- MUST enable graceful shutdown: `server.shutdown: graceful` and `spring.lifecycle.timeout-per-shutdown-phase` sourced from `DRAIN_TIMEOUT_MS`.
- HikariCP MUST be configured with explicit `maximum-pool-size = (2 * availableProcessors) + 1` and `connection-timeout: 2000` ms.
- NEVER call `System.exit()` directly.

## Telemetry
- MUST use Spring Boot Actuator + Micrometer with `micrometer-registry-otlp` and `micrometer-tracing-bridge-otel`.

## Configuration
- MUST use `@ConfigurationProperties` data classes annotated with `@Validated` and Bean Validation constraints.
- MUST bind via `@EnableConfigurationProperties(AppProperties::class)`.
- NEVER scatter `@Value("${some.prop}")` across controllers or services.

## Database
- MUST manage all schema changes with Flyway in `src/main/resources/db/migration/`.
- MUST use Spring Data JPA repository methods or `@Query` with named parameters. NEVER construct JPQL with string interpolation.
- MUST wrap all multi-step data operations in a single `@Transactional` service method.

## OpenAPI
- MUST use `springdoc-openapi-starter-webmvc-ui` (SpringDoc 2.x). NEVER Springfox.
- MUST add `@Operation`, `@ApiResponse`, and `@Tag` to every controller method.
- Swagger UI MUST be disabled in production or protected by authentication.

## Testing
- MUST use `@SpringBootTest(webEnvironment = MOCK)` + `MockMvc` for controller integration tests. NEVER `RANDOM_PORT`.
- MUST use `@WebMvcTest` for isolated controller slice tests.
- MUST use `@DataJpaTest` with Testcontainers Postgres for repository tests. NEVER H2.
- MUST configure Logback with `NullAppender` in `logback-test.xml`.
- MUST achieve 100% coverage across `controller/`, `service/`, and `repository/` via Kover. Exclude `Application.kt` and `domain/`.
