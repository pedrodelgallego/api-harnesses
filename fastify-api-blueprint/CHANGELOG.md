# Changelog

## 0.1.0

- Initial release.
- Violations table: 16 violations (15 ERROR, 1 SHOULD NOT) covering missing TypeBox schema, raw error throws, `exposeServerError: true`, wildcard CORS on authenticated routes, missing signal handlers, missing health/readiness probes, missing external call timeouts, unhandled external failures, retry without idempotency-key dedup, DB pool exhaustion without 503, route tested with real network, DB mocked in component tests, and coverage below 100%.
- Sections: Stack, Project Structure, Security, Plugin Registration Order, Routes, Logging, Lifecycle & Resilience, Telemetry, Configuration, Database, OpenAPI Documentation, Testing.
