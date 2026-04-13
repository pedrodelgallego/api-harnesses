# Fastify API Blueprint

## Scope
This file maps the general `api-*` harnesses to concrete Fastify implementation rules. It MUST NOT redefine the general API contract.

## Stack
- MUST use Node.js 22 LTS.
- MUST use TypeScript strict mode.
- MUST use Fastify 5.
- MUST use TypeBox for schema definitions.
- MUST use Fastify's built-in AJV validation and serialization path.
- MUST use Drizzle for database access.
- MUST use `@fastify/jwt` only for JWT verification, not token issuance.
- MUST use Vitest with `fastify.inject()` for HTTP-layer tests.

## Project Structure
- `package/api/app.ts` MUST build and export the Fastify app and MUST NOT call `listen()`.
- `package/api/server.ts` MUST be the only file that calls `listen()`.
- `package/api/plugins/` MUST contain Fastify plugins.
- `package/api/routes/` MUST contain route registrations grouped by resource.
- `package/api/schemas/` MUST contain shared TypeBox schemas.
- `package/api/db/` MUST contain the Drizzle client, schema, and migrations.

## Plugin Rules
- Custom plugins MUST use `fastify-plugin` unless encapsulation is intentionally required.
- Security plugins MUST register before route plugins.
- Telemetry instrumentation MUST register before route plugins.
- OpenAPI plugins MUST register after security plugins and before route plugins.

## Routes
- All public routes MUST live under `/v1`.
- Every route MUST declare `schema` for every relevant part: `params`, `querystring`, `headers`, `body`, and `response`.
- Response schemas MUST be declared per status code.
- Protected routes MUST use `preHandler: [fastify.authenticate]`.
- Route handlers MUST delegate business logic to services; they MUST NOT contain orchestration-heavy domain logic.
- Every route that accepts a body MUST set an explicit `bodyLimit` constant at module scope.

## Validation and Serialization
- AJV MUST be configured once during app construction.
- MUST keep `allErrors: false`.
- SHOULD use `coerceTypes: 'array'`.
- SHOULD use `useDefaults: true`.
- MUST define a schema error normalizer so client errors map to the RFC 9457 response shape.
- MUST NOT expose raw AJV errors to clients.
- Shared schemas MUST be registered once and referenced by `$ref`.
- Route files SHOULD avoid inline schema duplication.

## Logging
- MUST use Fastify's built-in Pino logger integration.
- Logger configuration MUST be passed directly to `fastify()` in `app.ts`.
- Tests SHOULD build the app with logging disabled.
- MUST create or bind `correlationId` in `onRequest`.
- MUST echo `X-Correlation-ID` in `onSend`.

## Security
- MUST register `@fastify/helmet`.
- MUST register `@fastify/cors` with an explicit allowlist function or equivalent explicit validation.
- MUST NOT use `origin: true` or `origin: '*'` for authenticated routes.
- MUST set `exposeServerError: false` where Fastify error helpers are used.
- MUST attach decoded JWT claims to `request.user` only after verification.

## Resilience and Lifecycle
- MUST expose `GET /healthz` and `GET /readyz`.
- `/healthz` and `/readyz` MUST skip auth.
- MUST implement graceful shutdown with `app.close()`.
- MUST handle `SIGTERM` and `SIGINT`.
- MUST enforce a hard drain timeout from configuration.
- `uncaughtException` and `unhandledRejection` MUST log at `fatal`, start shutdown, and exit non-zero only after shutdown handling.

## Telemetry
- MUST initialize telemetry before building the app.
- MUST register Fastify telemetry instrumentation before routes.
- `/healthz` and `/readyz` SHOULD opt out of tracing and metrics.
- MUST shut telemetry down during graceful shutdown.

## Configuration
- MUST load runtime configuration from environment variables.
- MUST validate config at startup with a typed schema.
- MUST fail startup when required config is missing or invalid.
- MUST NOT rely on fallback secrets in code.
- `buildApp(envData?)` MAY accept injected config for tests to avoid mutating global process state.

## Database
- Drizzle schema MUST live in `package/api/db/schema.ts`.
- Migrations MUST live in `package/api/db/migrations/`.
- MUST use the Drizzle query builder or parameterized SQL helpers.
- MUST NOT use interpolated SQL strings.

## OpenAPI
- MUST generate OpenAPI from route schemas.
- Every route MUST define `summary`, `description`, and `tags`.
- Protected routes MUST define bearer security metadata.
- Swagger UI MUST be disabled in production or protected by authentication.

## Testing
- HTTP-layer tests MUST use `fastify.inject()`.
- Tests MUST NOT require a live server port.
- `buildApp(envData?)` SHOULD support test-time config injection.
- Component tests MAY use a real local Postgres instance.
- Component tests MUST NOT mock Drizzle and claim database integration coverage at the same time.
