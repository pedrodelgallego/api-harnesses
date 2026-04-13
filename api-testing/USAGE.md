# Usage

## Referencing from a blueprint spec

Add the following line under the Testing section of your blueprint spec to pull in these rules:

```markdown
Implements [api-testing harness](../../api-testing/harness/index.md).
```

Framework-specific blueprints (Fastify, Go, Rust, Kotlin, Spring Boot) already implement this harness. For custom stacks, reference it directly.

## What to implement

1. **Unit tests** — cover all service/business logic functions independently of HTTP.
2. **Component tests** — test all routes via the framework test client (no real network); use a real database in Docker; reset state in `beforeEach`.
3. **Contract tests** — generate and publish Pact contracts from consumer tests; verify on the provider in CI.
4. **Coverage** — configure 100% thresholds on lines, branches, and functions for application code; exclude entry points and generated files.

## Key patterns

Export a `resetStore()` from every stateful in-memory module that mutates existing data structures in-place:

```ts
export function resetStore() {
  STORE.clear();
  for (const item of seed) STORE.set(item.id, { ...item });
}
```

Use `/* v8 ignore */` only for branches that require a running process (e.g., logger ternaries). Always add a comment explaining why.

## Running coverage

```bash
# Node.js / Vitest
npx vitest run --coverage

# Go
go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out

# Rust
cargo tarpaulin --out Html

# Kotlin / JVM
./gradlew koverHtmlReport
```
