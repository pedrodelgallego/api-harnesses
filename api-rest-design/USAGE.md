# Usage

## Referencing from a blueprint spec

Add the following line under the Routes or API Design section of your blueprint spec to pull in these rules:

```markdown
Implements [api-rest-design harness](../../api-rest-design/harness/index.md).
```

## What to implement

1. **URLs** — plural nouns, kebab-case, no verbs, nesting max two levels deep.
2. **Status codes** — follow the status code table exactly; `201 + Location` on creation, `204` on empty body, `400` for validation failures.
3. **Error format** — RFC 7807 Problem Details (`application/problem+json`) with `type`, `title`, `status`, `detail`, `instance`, and `code`. Add `errors[]` array on `400`.
4. **Response envelope** — wrap all responses: `{ "data": ... }` for single resources, `{ "data": [...], "meta": { ... } }` for collections.
5. **Pagination** — cursor-based by default; enforce a server-side `limit` cap; return `200` with `data: []` on empty pages.
6. **Idempotency** — accept `Idempotency-Key` on `POST` endpoints that create resources or trigger side effects.
7. **Content negotiation** — return `415` if `Content-Type` is not `application/json` on mutating requests; `406` if `Accept` is unsupported.

## Verifying compliance

Use Spectral with an OAS ruleset to catch URL, status code, and schema violations automatically:

```bash
npx @stoplight/spectral-cli lint openapi.yaml --ruleset .spectral.yaml
```

Check RFC 7807 format on error responses:

```bash
curl -s -X POST https://your-api/v1/users -H "Content-Type: application/json" \
  -d '{}' | jq '.type, .status, .code, .errors'
```
