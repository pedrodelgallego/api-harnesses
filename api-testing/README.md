# api-testing

High coverage numbers hide real failures when the database is mocked, assertions check only status codes, or the pyramid is inverted. Tests pass on PRs then fail after a migration renames a column. This harness closes those gaps: 7 ERROR-level rules that make the test suite a reliable signal.

## Who should use it

Any team writing automated tests for REST APIs who wants confidence that the suite catches real regressions. Language and framework agnostic; compose with a language-specific blueprint or reference directly for review criteria.

## How to use it

Add as a dependency in your blueprint spec or reference directly. The violations table — 7 ERROR, 1 SHOULD NOT — provides concrete code review criteria and CI gates.

## What it contains

- **Test pyramid** — unit → component → contract → e2e; more tests at each lower layer; never inverted; unit tests for service logic independent of HTTP required
- **Assertions** — every positive test asserts all four dimensions: status code, headers, body schema, specific field values; at least one negative case per endpoint
- **Component tests** — real database in Docker, never mocked; state reset in `beforeEach`, never `beforeAll`; `resetStore()` must mutate existing data structures in-place (`Map.clear()`, not `new Map()`) so the module reference stays valid
- **Coverage suppression** — `/* v8 ignore */` only for structurally unreachable branches; always with an explanatory comment; never to skip testable paths like 429 handlers or circuit breaker open states
- **Contract testing** — consumer-driven contracts (CDC); provider verifies all consumer contracts in CI; not for stateful or scenario-sequence workflows
- **Test data** — URLs, credentials, and IDs loaded from config, never hardcoded; fixture files for parameterized scenarios; data generated or seeded programmatically
- **Organisation & debuggability** — one file per route, one directory per test type; tests independent, no shared mutable fixtures, no execution-order dependencies
