# Changelog

## 0.1.0

- Initial release.
- Stack: Kotlin stable, JVM 21, Spring Boot 3.x, Spring MVC, Jackson + jackson-module-kotlin, Bean Validation, Spring Data JPA + Hibernate, Spring Security OAuth2 Resource Server, SLF4J + Logback + logstash-logback-encoder, `@ConfigurationProperties`, Flyway, SpringDoc 2.x, testcontainers, Kover.
- Compiler plugin rules: `kotlin-allopen` (`plugin.spring`) and `kotlin-jpa` are mandatory and must not be hand-replaced with `open` modifiers.
- Violations table: 15 violations (all ERROR) covering JPA entity returned directly from a controller, `@RequestBody` without `@Valid`, permissive CORS on authenticated routes, `permitAll()` outside of whitelisted paths, undocumented `csrf.disable()`, `data class` used for a JPA entity, `FetchType.EAGER` on `@OneToMany`/`@ManyToMany`, entity accessed in a lazy load outside a transaction, OSIV enabled (`open-in-view=true`), raw exception message in JSON response, `@Value` used for structured config, Springfox instead of SpringDoc, `@DataJpaTest` with H2 instead of Testcontainers Postgres, `@Transactional` on a `@SpringBootTest` integration test, and `RANDOM_PORT` used for controller tests.
- Sections: Stack, Compiler Plugins, Project Structure, Security, Spring Security Configuration Order, Routes, Validation & Serialization, JPA Entities, Transactions, Logging, Lifecycle & Resilience, Telemetry, Configuration, Database, OpenAPI Documentation, Testing.
