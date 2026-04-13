# Changelog

## 0.1.0

- Initial release.
- Stack: Kotlin stable, JVM 21, Ktor, kotlinx-serialization, Konform, Exposed DSL, com.auth0:java-jwt, SLF4J + Logback + logstash-logback-encoder, Hoplite, Flyway, ktor-swagger-ui, testcontainers-kotlin, Kover.
- Violations table: 11 violations (all ERROR) covering unvalidated request bodies, raw exception messages in JSON responses, `anyHost()` CORS on authenticated routes, JWT claims without null-safe handling, blocking IO on coroutine threads (`runBlocking`/`Thread.sleep` in handlers), missing body size limits, `Any`/`Map<String, Any>` as request or response type, Exposed blocking `transaction {}` from a coroutine handler, DB mocked in integration tests, `System.getenv()` inside tests, and real `embeddedServer.start()` in tests.
- Sections: Stack, Project Structure, Security, Plugin Installation Order, Routes, Validation & Serialization, Logging, Lifecycle & Resilience, Telemetry, Configuration, Database, OpenAPI Documentation, Testing.
