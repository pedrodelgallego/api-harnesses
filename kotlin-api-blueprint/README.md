# kotlin-api-blueprint

Calling blocking `transaction{}` inside a coroutine handler is a silent deadlock. JPA proxies conflict with Kotlin data classes in ways that surface at runtime. This blueprint chooses Ktor over Spring Boot and Exposed over JPA to stay coroutine-native throughout, and documents the rules that keep it that way.

## Who should use it

Teams or individuals building REST APIs with Kotlin who want a lightweight, coroutine-first framework over the Spring ecosystem. Best for new services where Kotlin idioms (data classes, sealed classes) should map cleanly to the HTTP layer.

## How to use it

Pull the spec into specforge or pass it to a code-generation agent. All eight cross-cutting harnesses (design, resilience, security, security headers, logging, telemetry, testing, versioning) are composed in as dependencies.

## What it contains

- **Stack** — Kotlin stable, JVM 21; Ktor never Spring Boot; kotlinx-serialization never Jackson; Konform for validation never Hibernate Validator; Exposed DSL with `newSuspendedTransaction(Dispatchers.IO)` for all DB calls (blocking `transaction{}` in a coroutine handler is an ERROR); `com.auth0:java-jwt` for validation only; SLF4J + Logback + logstash-logback-encoder; Hoplite for config; Flyway; ktor-swagger-ui; testcontainers-kotlin; Kover
- **Project structure** — `Application.kt` entry only; `app/App.kt` router factory; `config/Config.kt`; `routes/` one file per resource; `plugins/` one concern per file; `service/`; `model/`; `db/tables/`
- **Security** — Ktor CORS plugin with explicit origin allowlist; rate limiting plugin; JWT via Ktor Authentication plugin, never manual header parsing; security headers plugin
- **Plugin installation order** — enforced; order matters for Ktor plugin composition
- **Routes** — `/v1` prefix from first commit; Konform `validate()` before any field access; JWT via Authentication plugin; `bodyLimit` configured; no business logic in route handlers
- **Validation & serialization** — Konform `validate()` at route entry; validation errors translated to RFC 7807 format; never expose raw Konform error internals
- **Logging** — SLF4J + Logback only; JSON via logstash-logback-encoder in production; MDC correlation ID bound per request with `MDC.clear()` after each call; `NullAppender` in `logback-test.xml`
- **Lifecycle & resilience** — JVM shutdown hook calling `server.stop()` with timeout from `DRAIN_TIMEOUT_MS`; `/healthz` and `/readyz` exposed; HikariCP pool exhaustion returns 503
- **Telemetry** — opentelemetry-kotlin + opentelemetry-ktor registered before routes; tracer provider shutdown in JVM shutdown hook; health probes excluded
- **Configuration** — Hoplite data classes; hard-fail on missing vars; config injected into app factory for test overrides
- **Database** — Exposed DSL; `newSuspendedTransaction(Dispatchers.IO)` always; Flyway migrations; HikariCP pool sizing
- **OpenAPI documentation** — ktor-swagger-ui code-first annotations; Swagger UI disabled in production; `securitySchemeName("bearerAuth")` on protected routes
- **Testing** — Ktor `testApplication` for route tests; testcontainers-kotlin Postgres for integration tests; 100% coverage on `routes/` and `service/` via Kover
