# Usage

## 1. Apply the spec to your project

Reference `spec/index.md` when scaffolding or pass it directly to an agent:

```bash
claude -p "Read harnesses/fastify-api-blueprint/spec/index.md and scaffold a new Fastify API for [your domain]"
```

## 2. Bootstrap a new project

```bash
mkdir my-api && cd my-api
npm init -y
npm install fastify @fastify/jwt @fastify/cors @fastify/helmet @fastify/env @fastify/sensible \
  @fastify/rate-limit @fastify/swagger @fastify/swagger-ui @fastify/otel \
  @sinclair/typebox drizzle-orm postgres fastify-plugin
npm install --save-dev typescript @types/node vitest drizzle-kit tsx
```

The spec expects this layout:

```
src/
  app.ts          # builds Fastify instance — NO listen()
  server.ts       # calls listen() only
  plugins/        # custom plugins wrapped with fp()
  routes/         # encapsulated route plugins (one per resource)
  schemas/        # shared TypeBox schemas
  db/
    schema.ts     # Drizzle table definitions
    index.ts      # Drizzle client
    migrations/   # Drizzle migration files
tsconfig.json
vitest.config.ts
```

## 3. Required tooling

Install before running codegen or migrations:

```bash
npm install --save-dev drizzle-kit
```

## 4. Codegen workflow

After editing `src/db/schema.ts`, generate and apply migrations:

```bash
npx drizzle-kit generate
npx drizzle-kit migrate
```

After editing routes, regenerate OpenAPI docs (done automatically via `@fastify/swagger` at runtime — no separate step required).

## 5. Running tests

```bash
npx vitest run --coverage
```

Integration tests require a running Postgres instance:

```bash
docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=test postgres:16
```

## 6. Coverage

```bash
npx vitest run --coverage --reporter=html
open coverage/index.html
```

The spec requires 100% lines, branches, functions, and statements. Configure thresholds in `vitest.config.ts`:

```ts
export default {
  test: {
    coverage: {
      provider: 'v8',
      thresholds: { lines: 100, branches: 100, functions: 100, statements: 100 },
      exclude: ['src/server.ts', 'src/db/migrations/**'],
    },
  },
}
```
