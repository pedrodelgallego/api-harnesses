# REST API Design Harness

## Scope
These rules define the protocol contract for HTTP APIs. They are framework-agnostic and apply to any implementation.

## General
- MUST prefer resource-oriented design.
- MUST optimize for domain clarity over cosmetic REST purity.
- MUST document any intentional exception.
- SHOULD version paths under `/v{major}`.

## URLs
- MUST use lowercase and kebab-case in paths.
- MUST NOT use file extensions.
- SHOULD use plural nouns for top-level resource collections.
- SHOULD avoid verbs in paths when a resource model is reasonable.
- MAY model non-CRUD actions as command resources such as `/password-resets` or `/exports`.
- MUST use nesting only for clear containment or ownership.
- SHOULD avoid nesting deeper than 2 levels unless it materially improves clarity.
- MUST use query parameters for filtering, sorting, pagination, sparse fieldsets, and expansions.

## Methods
- GET MUST be read-only.
- POST MUST create resources or trigger non-idempotent operations.
- PUT MUST replace the full client-writable representation.
- PATCH MUST update only provided fields.
- PATCH MUST leave absent fields unchanged.
- DELETE MUST remove the resource.
- DELETE SHOULD NOT require a request body.

## Status Codes
- 200 = success with response body.
- 201 = resource created; MUST include `Location`.
- 202 = accepted for asynchronous processing; SHOULD include `Location` to an operation resource.
- 204 = success with no response body.
- 400 = invalid request, including validation failures when 422 is not used.
- 401 = unauthenticated.
- 403 = authenticated but not authorized.
- 404 = resource not found.
- 405 = method not allowed.
- 406 = unsupported `Accept`.
- 409 = conflict, including idempotency-key payload mismatch.
- 412 = precondition failed, including `If-Match` mismatch.
- 413 = payload too large.
- 415 = unsupported `Content-Type`.
- 429 = rate limited; SHOULD include `Retry-After`.
- 500 = internal server error.
- 502 = bad gateway or upstream protocol failure.
- 503 = temporary dependency or service unavailability; SHOULD include `Retry-After`.
- 504 = upstream timeout.
- MUST NOT return 2xx for errors.
- MUST NOT return 5xx for client mistakes.

## Media Types and Negotiation
- MUST use JSON for request and response bodies unless explicitly documented otherwise.
- MUST set `Content-Type: application/json` on every non-error response with a body.
- MUST use `application/problem+json` for problem responses.
- MUST validate `Content-Type` on POST, PUT, and PATCH; MUST return 415 on mismatch.
- MUST validate `Accept`; MUST return 406 when no supported representation is acceptable.
- MUST accept `Accept: */*` when JSON is supported.

## JSON Conventions
- MUST use camelCase for JSON field names.
- MUST keep public field names stable.
- MUST NOT expose internal schema names.
- MUST use this single-resource envelope:

```json
{ "data": { ... } }
```

- MUST use this collection envelope:

```json
{ "data": [...], "meta": { "limit": 20, "nextCursor": null, "total": null } }
```

- `total` MAY be `null` when counting is expensive or unsupported.
- MUST define nullability explicitly.
- MUST use `null` only when semantically meaningful.
- MUST define enum values explicitly and keep them stable.
- MUST encode timestamps in RFC 3339 format.
- SHOULD prefer UTC timestamps or explicit offsets.

## Resource Identity
- MUST expose stable resource identifiers.
- MUST treat IDs as opaque.
- MUST NOT require clients to infer meaning from IDs.
- MUST keep canonical URLs stable once published unless explicitly versioned or deprecated.

## Collections
- MUST paginate every collection.
- MUST enforce a server-side maximum `limit`.
- MUST define a default `limit`.
- SHOULD prefer cursor pagination.
- MUST NOT use offset pagination on large or volatile collections.
- MUST validate pagination inputs.
- MUST return `200` with `data: []` for empty results.

## Filtering, Sorting, and Field Selection
- MUST whitelist filterable fields.
- MUST whitelist sortable fields.
- MUST validate every filter and sort input.
- MUST reject unknown or unsupported filter and sort fields with 400.
- MUST use public field names, not internal schema names.
- SHOULD define one sparse-fieldset parameter such as `fields`.
- MUST validate requested fields against an allowlist.

## Writes
- POST create endpoints MUST return 201 with the created resource or 202 if asynchronous.
- PUT clients MUST send the full client-writable representation.
- PUT MUST NOT silently behave like PATCH.
- PATCH MUST update only provided fields.
- PUT and PATCH SHOULD return 200 with the updated resource.
- PUT and PATCH MAY return 204 when no representation is returned.
- MUST define how immutable or server-managed fields are handled on write.
- MUST consistently reject or ignore unknown input fields; the policy MUST be uniform across the API.

## Concurrency Control
- SHOULD support ETag on mutable resources.
- SHOULD support `If-Match` for PUT and PATCH.
- MUST return 412 on precondition mismatch when preconditions are required or supplied.
- MUST define whether writes without preconditions are allowed.

## Idempotency
- MUST support `Idempotency-Key` on POST endpoints that create resources or cause side effects.
- MUST scope idempotency keys per client.
- MUST retain keys for at least 24 hours.
- MUST persist enough state to replay a completed response.
- MUST NOT re-execute a completed request for the same key and same payload.
- MUST return 409 if the same key is reused with a different payload.

## Asynchronous and Bulk Operations
- MUST use 202 when work is accepted but not completed before the response.
- SHOULD expose an operation resource via `Location`, response body, or both.
- MUST define operation states such as `pending`, `running`, `succeeded`, `failed`, and `canceled`.
- MUST make completion and failure observable to clients.
- MUST explicitly define bulk semantics as one of: atomic all-or-nothing, per-item results, or asynchronous batch job.
- MUST NOT leave partial-success behavior implicit.

## Errors
- MUST use RFC 9457 Problem Details with `application/problem+json`.
- MUST include `type`, `title`, `status`, `detail`, and `instance`.
- `status` MUST match the HTTP status code.
- `instance` MUST identify the specific request occurrence.
- MAY include extension members.
- MUST include a stable machine-readable `code` extension.
- 400 validation errors MUST include `errors[]` entries with `field`, `code`, and `detail`.
- MUST NOT leak internals such as stack traces, SQL, hostnames, credentials, or dependency details.
