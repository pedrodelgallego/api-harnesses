# Changelog

## 0.1.0

- Initial release.
- Stack: Go 1.22+, Chi v5, go-playground/validator v10, sqlc, golang-jwt/jwt v5, log/slog, goose, swaggo/swag, testify, testcontainers-go.
- Violations table: 12 violations (all ERROR) covering unvalidated handlers, raw error responses in JSON, permissive CORS on authenticated routes, JWT claims without typed context keys, missing body size limits, `interface{}`/`any` as request or response type, SQL string interpolation, missing transaction wrapping, DB pool exhaustion without 503, real `net.Listen` in tests, DB mocked in integration tests, and `os.Getenv` inside tests.
- Sections: Stack, Project Structure, Security, Middleware Registration Order, Routes, Validation & Serialization, Logging, Lifecycle & Resilience, Telemetry, Configuration, Database, OpenAPI Documentation, Testing.
