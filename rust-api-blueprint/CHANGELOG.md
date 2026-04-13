# Changelog

## 0.1.0

- Initial release.
- Stack: Rust stable, Tokio, Axum, tower-http, validator crate, sqlx with `query!` macros, jsonwebtoken, tracing + tracing-subscriber + tracing-opentelemetry, envy + serde, utoipa, testcontainers.
- Violations table: 13 violations (all ERROR) covering unvalidated extractors, raw error strings in JSON responses, `CorsLayer::permissive()` on authenticated routes, JWT claims without type-safe extension keys, `unwrap()`/`expect()` in handler or service code, missing body size limits, `serde_json::Value` as request or response type, SQL string interpolation, missing transaction wrapping, DB pool exhaustion without 503, real `TcpListener` in tests, DB mocked in integration tests, and `std::env::var()` inside tests.
- Sections: Stack, Project Structure, Security, Middleware Registration Order, Routes, Validation & Serialization, Logging, Lifecycle & Resilience, Telemetry, Configuration, Database, OpenAPI Documentation, Testing.
