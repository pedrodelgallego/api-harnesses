# fastify-api-blueprint

Left open, Fastify projects drift: handlers grow business logic, routes lack TypeBox schemas, and tests start real servers instead of using `fastify.inject()`. This blueprint locks the decisions in upfront so every Fastify API in the organization looks the same and a spec-driven agent can implement one without ambiguity.

## Who should use it

Teams or individuals building REST APIs on Node.js 22 LTS with TypeScript. Best for new projects, greenfield microservices, and AI-assisted development where consistency across generated output matters.

## How to use it

Pull the spec into specforge or pass it to a code-generation agent. All eight cross-cutting harnesses (design, resilience, security, security headers, logging, telemetry, testing, versioning) are composed in as dependencies.

## What it contains

- **Stack** — Node.js 22 LTS + TypeScript strict; Fastify 5 never Express; TypeBox never raw JSON Schema; Drizzle never Prisma; `@fastify/jwt` for validation only; Vitest + `fastify.inject()` never supertest
- **Project structure** — `src/app.ts` builds the instance (no `listen()`); `src/server.ts` calls `listen()` only; `src/plugins/` wrapped with `fp()`; `src/routes/` as encapsulated plugins; `src/schemas/`; `src/db/`
- **Security** — `@fastify/helmet`, `@fastify/cors` with explicit origin allowlist, `@fastify/rate-limit` with Redis store, `@fastify/sensible` with `exposeServerError: false`
- **Plugin registration order** — all custom plugins wrapped with `fp()` unless encapsulated scope is required
- **Routes** — TypeBox schema on every route covering body, params, querystring, response; `preHandler: [fastify.authenticate]` on protected routes; `bodyLimit` as a module-level constant; no business logic in handlers
- **Validation & serialization** — Ajv v8 configured once in `app.ts`; schemas in `src/schemas/`, never inlined; `Type.Strict()` on response schemas; `schemaErrorFormatter` normalizes errors before they reach clients
- **Logging** — Pino only; `logger: false` in tests; `pino-pretty` in development only; `correlationId` and `service` bound via child logger in `onRequest`; redact paths in Pino config
- **Lifecycle & resilience** — SIGTERM/SIGINT/uncaughtException/unhandledRejection all handled; `app.close()` on shutdown; hard drain timeout from `DRAIN_TIMEOUT_MS` parsed as integer; `/healthz` and `/readyz` with `otel: false`; 503 on DB pool exhaustion
- **Telemetry** — `@fastify/otel` registered before any route; `initTelemetry()` before `buildApp()`; `shutdownTelemetry()` in graceful shutdown sequence
- **Configuration** — `@fastify/env` with TypeBox schema; hard-fail on missing vars; `buildApp(envData?)` accepts partial config for test injection without mutating `process.env`
- **Database** — Drizzle schema in `src/db/schema.ts`; migrations in `src/db/migrations/`; pool sized `(2 × CPU cores) + 1`; never `db.execute()` with interpolated input
- **OpenAPI documentation** — `@fastify/swagger` and `@fastify/swagger-ui` after security plugins, before routes; Swagger UI disabled or auth-protected in production; `summary`, `tags`, `security` on every route
- **Testing** — `fastify.inject()` for all route tests; real Postgres in Docker for component tests, never mock Drizzle; 100% lines/branches/functions/statements via Vitest v8
