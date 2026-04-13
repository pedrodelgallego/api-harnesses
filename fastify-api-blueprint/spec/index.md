# Fastify API Blueprint

## Stack
- MUST use Node.js 22 LTS.
- MUST use TypeScript strict mode (`"strict": true` in `tsconfig.json`).
- MUST use Fastify 5. NEVER Express, NEVER Hono, NEVER Koa.
- MUST use TypeBox for schema definitions. NEVER raw JSON Schema objects.
- MUST use Fastify's built-in AJV validation and serialization path.
- MUST use Drizzle for database access. NEVER Prisma, NEVER TypeORM.
- MUST use `@fastify/jwt` for JWT validation only. NEVER issue tokens from app code; use an IDaaS provider.
- MUST use Vitest with `fastify.inject()` for HTTP-layer tests. NEVER supertest, NEVER a real listening server in tests.
- MUST use `drizzle-kit` for migrations. NEVER hand-applied SQL.

## Project Structure

MUST follow this layout exactly:

- `src/app.ts` — Builds and exports the Fastify instance. MUST NOT call `listen()`.
- `src/server.ts` — ONLY file that calls `listen()`.
- `src/plugins/` — Fastify plugins wrapped with `fastify-plugin`. One concern per file.
- `src/routes/` — Route registrations grouped by resource. Each file is an encapsulated plugin.
- `src/schemas/` — Shared TypeBox schemas registered with `fastify.addSchema()`.
- `src/db/schema.ts` — Drizzle table definitions.
- `src/db/index.ts` — Drizzle client and pool setup.
- `src/db/migrations/` — Drizzle migration files.

## Security

Implements [api-security harness](../../api-security/harness/index.md) and [api-security-headers harness](../../api-security-headers/harness/index.md).

Fastify-specific implementation:

- MUST register `@fastify/helmet` before route plugins.
- MUST register `@fastify/cors` with an explicit allowlist function or `origin` array from config. NEVER `origin: true` or `origin: '*'` on authenticated routes.
- MUST register `@fastify/rate-limit` with a Redis store. NEVER in-memory rate limiting in multi-instance deployments.
- MUST register `@fastify/sensible` with `exposeServerError: false`. NEVER expose internal error details to clients.
- MUST attach decoded JWT claims to `request.user` only after verification via `fastify.authenticate`. NEVER read the `Authorization` header manually inside a handler.
- MUST use `preHandler: [fastify.authenticate]` on all protected routes. NEVER inline auth checks inside handlers.

## Plugin Registration Order

MUST install plugins in this order in `src/app.ts`:

1. `@fastify/env` (config validation — must be first)
2. `@fastify/helmet`
3. `@fastify/cors`
4. `@fastify/rate-limit`
5. `@fastify/jwt` (auth plugin)
6. `@fastify/otel` (telemetry — before routes)
7. `@fastify/swagger`
8. `@fastify/swagger-ui`
9. Route plugins (`src/routes/`)

Custom plugins MUST use `fastify-plugin` unless encapsulation is intentionally required. NEVER register security plugins after route plugins.

## Routes

Implements [api-versioning harness](../../api-versioning/harness/index.md). MUST prefix all routes with `/v1` from day one:

```ts
app.register(userRoutes, { prefix: '/v1' })
```

MUST declare `schema` on every route covering every relevant part: `params`, `querystring`, `headers`, `body`, and `response`. Response schemas MUST be declared per status code.

MUST set an explicit `bodyLimit` constant at module scope on every route that accepts a body:

```ts
const BODY_LIMIT = 1_048_576 // 1 MB

app.post('/users', { bodyLimit: BODY_LIMIT, schema: { ... } }, handler)
```

MUST expose `GET /healthz` and `GET /readyz`. Both MUST skip auth and rate limiting.

NEVER put business logic in route handlers — delegate to a service function.

## Validation & Serialization

All request schemas MUST be defined with TypeBox. All response schemas MUST use `Type.Strict()` to strip unknown fields. NEVER inline schema objects — define in `src/schemas/` and reference by `$ref`.

- NEVER expose raw AJV errors to clients.
- NEVER use `interface{}` or untyped `object` as a request or response schema type.
- NEVER call `reply.send()` with data that bypasses the declared response schema.

### AJV Configuration

MUST configure AJV once during app construction in `src/app.ts`:

```ts
const app = Fastify({
  ajv: {
    customOptions: {
      allErrors: false,       // fail fast on first error
      coerceTypes: 'array',   // coerce query strings
      useDefaults: true,      // apply schema defaults
    },
  },
})
```

MUST register shared schemas once and reference them by `$ref`. NEVER duplicate schema definitions across route files.

### Error Formatting

MUST define a `schemaErrorFormatter` so client validation errors map to RFC 9457 Problem Details format. NEVER let raw AJV error arrays reach the response:

```ts
const app = Fastify({
  schemaErrorFormatter(errors, dataVar) {
    return new Error(JSON.stringify({
      type: 'https://example.com/errors/validation',
      title: 'Validation Error',
      status: 400,
      errors: errors.map(e => ({ field: e.instancePath, message: e.message })),
    }))
  },
})
```

## Logging

Implements [api-logging harness](../../api-logging/harness/index.md). Fastify-specific setup:

MUST use Fastify's built-in Pino logger integration. NEVER add a separate logger library. Logger configuration MUST be passed directly to `fastify()` in `app.ts`:

```ts
const app = Fastify({
  logger: {
    level: process.env.LOG_LEVEL ?? 'info',
    transport: process.env.NODE_ENV === 'development'
      ? { target: 'pino-pretty' }
      : undefined,
    redact: ['req.headers.authorization', 'req.body.password', 'req.body.token'],
  },
})
```

MUST create or bind `correlationId` in `onRequest` and echo `X-Correlation-ID` in `onSend`:

```ts
app.addHook('onRequest', (req, reply, done) => {
  const id = req.headers['x-correlation-id'] as string ?? randomUUID()
  req.log = req.log.child({ correlationId: id, service: SERVICE_NAME })
  reply.header('X-Correlation-ID', id)
  done()
})
```

MUST build the app with `logger: false` in tests — NEVER emit log output during test runs.

MUST redact `Authorization`, `Cookie`, `password`, `token`, and `secret` fields via Pino's `redact` option. NEVER log them verbatim.

## Lifecycle & Resilience

Implements [api-rest-resilience harness](../../api-rest-resilience/harness/index.md). Fastify-specific implementation:

**Shutdown:**

MUST handle `SIGTERM` and `SIGINT` in `src/server.ts`. MUST call `app.close()` with a hard drain timeout from `DRAIN_TIMEOUT_MS`:

```ts
const DRAIN_TIMEOUT_MS = parseInt(process.env.DRAIN_TIMEOUT_MS ?? '10000', 10)

const shutdown = async () => {
  setTimeout(() => {
    app.log.fatal('drain timeout exceeded — forcing exit')
    process.exit(1)
  }, DRAIN_TIMEOUT_MS).unref()
  await app.close()
  process.exit(0)
}

process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)
```

MUST handle `uncaughtException` and `unhandledRejection` — log at `fatal`, start shutdown, exit non-zero only after shutdown completes.

MUST parse `DRAIN_TIMEOUT_MS` as integer. NEVER pass raw string to `setTimeout`.

**Health & Readiness:**

MUST expose `GET /healthz` and `GET /readyz`. MUST skip auth, rate limiting, and OTel tracing on both.

**DB Pool:**

MUST size the connection pool to `(2 × os.cpus().length) + 1`. MUST return `503` immediately on pool exhaustion. NEVER queue indefinitely.

## Telemetry

Implements [api-telemetry harness](../../api-telemetry/harness/index.md). Fastify-specific setup:

MUST call `initTelemetry()` before `buildApp()` in `src/server.ts` — NEVER initialize OTel inside the app factory.

MUST register `@fastify/otel` before any route plugin.

MUST call `shutdownTelemetry()` in the graceful shutdown sequence before `process.exit()`.

MUST exclude `/healthz` and `/readyz` from tracing and metrics collection.

## Configuration

MUST load runtime configuration from environment variables using `@fastify/env` with a TypeBox schema. MUST fail startup when required config is missing or invalid:

```ts
const ConfigSchema = Type.Object({
  PORT:              Type.Number(),
  DATABASE_URL:      Type.String(),
  JWT_SECRET:        Type.String({ minLength: 32 }),
  ALLOWED_ORIGINS:   Type.String(),
  LOG_LEVEL:         Type.String({ default: 'info' }),
  DRAIN_TIMEOUT_MS:  Type.Number({ default: 10000 }),
})

await app.register(fastifyEnv, { schema: ConfigSchema, dotenv: false })
```

NEVER rely on fallback secrets in code. NEVER use `.env` files in production — use secrets manager injection.

`buildApp(envData?)` MAY accept injected config for tests to avoid mutating `process.env`:

```ts
export async function buildApp(envData?: Partial<AppConfig>) {
  const app = Fastify({ logger: !envData })
  await app.register(fastifyEnv, { schema: ConfigSchema, data: envData })
  // ...
  return app
}
```

## Database

MUST define all table schemas in `src/db/schema.ts` as Drizzle table objects.

MUST write all queries using the Drizzle query builder or parameterized SQL helpers via `drizzle-orm/sql`. NEVER use interpolated SQL strings or template literals in queries.

MUST use `drizzle-kit generate` and `drizzle-kit migrate` for all schema changes. Migration files live in `src/db/migrations/`. NEVER hand-apply SQL.

MUST wrap multi-step operations in a Drizzle transaction. NEVER leave partial writes on failure:

```ts
await db.transaction(async (tx) => {
  await tx.insert(users).values(newUser)
  await tx.insert(auditLog).values(auditEntry)
})
```

## OpenAPI Documentation

MUST generate OpenAPI from route schemas via `@fastify/swagger` — NEVER maintain a separate OpenAPI file.

MUST add `summary`, `description`, and `tags` to every route schema:

```ts
schema: {
  summary: 'Create a user',
  description: 'Creates a new user account. Requires authentication.',
  tags: ['users'],
  body: CreateUserSchema,
  response: { 201: UserResponseSchema },
}
```

Protected routes MUST define bearer security metadata. Swagger UI MUST be disabled in production or protected by authentication.

## Testing

Implements [api-testing harness](../../api-testing/harness/index.md). Fastify-specific rules:

- NEVER test HTTP routes with a real listening server. MUST use `fastify.inject()`.
- NEVER mock Drizzle queries in component tests and claim database integration coverage.
- NEVER call `os.Getenv` inside a test. MUST inject config via `buildApp(envData)`.

MUST use `buildApp(envData?)` for test config injection without mutating `process.env`:

```ts
const app = await buildApp({ DATABASE_URL: testDbUrl, JWT_SECRET: 'test-secret-32-chars-minimum' })
const response = await app.inject({ method: 'POST', url: '/v1/users', payload: { ... } })
expect(response.statusCode).toBe(201)
```

MUST build the app with `logger: false` in all tests.

MUST run component tests against a real Postgres instance (Docker / testcontainers). NEVER mock Drizzle for integration tests.

MUST reset database state between tests — truncate tables in `beforeEach` or use a transaction that rolls back after each test.

MUST achieve 100% coverage on lines, branches, functions, and statements across `src/routes/` and `src/service/`. Exclude `src/server.ts` and `src/db/migrations/` from coverage requirements. Configure thresholds in `vitest.config.ts`:

```ts
coverage: {
  provider: 'v8',
  thresholds: { lines: 100, branches: 100, functions: 100, statements: 100 },
}
```
