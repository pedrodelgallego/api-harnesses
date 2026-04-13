# api-rest-design

Without a shared design contract, every service invents its own URL structure, status codes, and error format. Consumers write bespoke error-handling code for each one. This harness defines the contract once — 17 ERROR-level rules — so a single client works across your entire API surface.

## Who should use it

Any team designing or reviewing REST HTTP APIs. Applies at design time, during code review, and as input to a spec-driven code generator. Language and framework agnostic; compose with a language-specific blueprint or reference directly.

## How to use it

Add as a dependency in your blueprint spec or reference directly. The violations table — 17 ERROR, 2 SHOULD NOT — drives code review and CI policy checks.

## What it contains

- **URLs** — nouns only, plural, kebab-case, max two nesting levels; no verbs in paths, no file extensions
- **HTTP methods** — `GET`/`DELETE` never mutate state; `DELETE` never carries a body; idempotency respected per verb
- **Status codes** — 201+Location on creation, 204 on empty body, 400 for validation, 503+Retry-After on downstream unavailability; never 2xx with an error payload
- **Request & response format** — `application/json` throughout; camelCase fields consistently; all responses wrapped in `{ "data": ... }` or `{ "data": [...], "meta": {...} }`
- **Error format** — RFC 7807 Problem Details with machine-readable `code` and `errors[]` array on 400; never expose stack traces, DB names, or internal paths
- **Pagination** — every collection endpoint paginated; cursor-first by default; server-side limit cap; empty pages return 200 with empty array, never 404
- **Filtering, sorting & field selection** — query parameters only; all filterable fields whitelisted; internal column names never exposed
- **Partial updates** — `PATCH` applies only fields present in the body; `PUT` replaces the entire resource; `If-Match`/ETag supported
- **Idempotency** — `Idempotency-Key` on POST endpoints that trigger side effects; same response replayed on retry; `409` on key reused with different body
- **Content negotiation** — `415` on wrong `Content-Type`; `406` on unsupported `Accept`; enforced globally, not per handler
