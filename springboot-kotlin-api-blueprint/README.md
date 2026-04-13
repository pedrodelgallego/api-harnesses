# springboot-kotlin-api-blueprint

JPA proxies conflict with Kotlin data classes. `FetchType.EAGER` on collections causes N+1 queries invisible in development. `@CrossOrigin` scattered across controllers bypasses the security filter chain. `spring.jpa.open-in-view=true` keeps transactions alive through view rendering. This blueprint documents the constraints that avoid those pitfalls and enforces the Spring idioms that make Kotlin and Spring work together.

## Who should use it

Teams building REST APIs with Spring Boot 3 and Kotlin in Java-ecosystem organizations where Spring is the standard. Particularly suited to teams migrating from Java to Kotlin who want idiomatic Kotlin patterns without leaving the Spring ecosystem.

## How to use it

Pull the spec into specforge or pass it to a code-generation agent. All eight cross-cutting harnesses (design, resilience, security, security headers, logging, telemetry, testing, versioning) are composed in as dependencies.

## What it contains

- **Stack** — Kotlin stable, JVM 21; Spring Boot 3.x with Spring MVC never WebFlux; Jackson + jackson-module-kotlin never Gson; Bean Validation `@Valid` for input; Spring Data JPA + Hibernate; Spring Security OAuth2 Resource Server for JWT; SLF4J + Logback + logstash-logback-encoder; `@ConfigurationProperties` never `@Value` for structured config; Flyway; SpringDoc 2.x never Springfox; testcontainers never H2; Kover
- **Compiler plugins** — `kotlin-allopen` (plugin.spring) and `kotlin-jpa` mandatory; without them, Spring's proxy generation and JPA's no-arg constructor requirement silently fail
- **Project structure** — `Application.kt` entry; `config/` (SecurityConfig, OpenApiConfig, AppProperties); `controller/`; `service/`; `repository/`; `domain/` entities; `dto/request/` and `dto/response/`; `exception/` with `@RestControllerAdvice` GlobalExceptionHandler
- **Security** — `SecurityFilterChain` deny-by-default; CORS only via `SecurityConfig`, never `@CrossOrigin`; JWT via OAuth2 Resource Server, never manual parsing; `@RequestBody` always paired with `@Valid`
- **Spring Security configuration order** — enforced; CSRF → CORS → session → JWT resource server → method security
- **Routes** — `/v1` prefix from first commit; `@RequestBody` always paired with `@Valid`; no business logic in controllers
- **Validation & serialization** — Bean Validation with `@Valid`; validation errors translated to RFC 7807 via `@RestControllerAdvice`; never expose raw `ConstraintViolation` details
- **JPA entities** — never `data class` for `@Entity` (Hibernate proxy conflicts); `FetchType.EAGER` banned on collections; `@EntityGraph` for association loading; `spring.jpa.open-in-view=false` mandatory
- **Transactions** — `@Transactional` on service layer, never controller; `readOnly = true` on read methods; self-invocation banned (bypasses proxy)
- **Logging** — SLF4J + Logback; logstash-logback-encoder for JSON; MDC correlation ID via `OncePerRequestFilter` with `MDC.clear()` in `finally`
- **Lifecycle & resilience** — Spring Boot graceful shutdown; `DRAIN_TIMEOUT_MS` via `@ConfigurationProperties`; HikariCP pool sizing; 503 on pool exhaustion
- **Telemetry** — Micrometer + OTLP; `micrometer-tracing-bridge-otel`; health probes excluded from observations
- **Configuration** — `@ConfigurationProperties` data classes with `@Validated`; hard-fail on missing vars; never `@Value` for structured config
- **Database** — Spring Data JPA repositories; Flyway migrations; parameterized queries via Spring Data; `@QueryHints` for read-only optimization
- **OpenAPI documentation** — SpringDoc 2.x; `@Operation` and `@ApiResponse` on every method; Swagger UI disabled in production; `@SecurityRequirement` on protected endpoints
- **Testing** — `@SpringBootTest(MOCK)` + MockMvc, never `RANDOM_PORT`; `@WebMvcTest` for controller slices; testcontainers Postgres for `@DataJpaTest`; 100% coverage on controller/service/repository via Kover
