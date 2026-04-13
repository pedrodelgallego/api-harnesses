# API Testing Harness

## Scope
These rules define testing strategy and coverage expectations. Framework-specific test mechanics belong in framework harnesses.

## Test Pyramid
- MUST follow the pyramid: unit -> component -> contract -> end-to-end.
- MUST have more tests at each lower layer than the one above.
- MUST keep service logic testable independently from HTTP.

## Layer Definitions
- Unit: single function or class with full mocking of collaborators.
- Component: one service boundary with external APIs and brokers mocked.
- Contract: consumer-provider interface verification without a live shared environment.
- End-to-end: full deployed system in a production-like environment.

## Assertions
Positive tests MUST assert:
- exact status code
- required response headers
- response schema
- specific field values or domain outcomes

Every endpoint MUST have negative tests covering at least one of:
- bad input
- missing required field
- wrong type
- unauthorized
- forbidden
- not found

## Isolation
- Tests MUST be independent and order-insensitive.
- Each test MUST own its setup and teardown.
- MUST reset mutable state before each test, not once per suite.
- MUST NOT share mutable fixtures or depend on execution order.

## Dependencies and Test Data
- Unit and component tests MUST NOT make real network calls.
- Component tests MAY use a local real database instance.
- MUST NOT use shared or production infrastructure.
- MUST load URLs, credentials, and IDs from config, not hardcode them.
- MUST generate, seed, or fixture test data programmatically.
- MUST NOT depend on production data.

## Contract Testing
- MUST use consumer-driven contracts for service-to-service APIs.
- Providers MUST verify all supported consumer contracts in CI.
- MUST fail the build on contract breach.
- MUST NOT use contract tests for stateful scenario workflows.

## Coverage and Suppression
- MUST cover happy-path and failure-path behavior.
- Coverage suppressions MUST be rare and justified.
- `/* v8 ignore */` MUST be used only for branches that are structurally unreachable through the chosen framework test client.
- Every ignore directive MUST explain why the branch is untestable and what would be needed to trigger it.
