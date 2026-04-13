# API Versioning Harness

## Scope
These rules define compatibility and version lifecycle policy. They are separate from endpoint design rules.

## Versioning Model
- MUST version the public HTTP API from day one.
- MUST use a major version in the path, for example `/v1`.
- MUST treat each path major version as a compatibility boundary.
- MUST keep versioning uniform across the API surface.
- MUST NOT mix path versioning and media-type versioning in the same API unless explicitly documented.

## Backward Compatibility Within a Major Version
- MUST preserve backward compatibility within a published major version unless an explicitly documented exception is approved.
- MUST NOT remove a field, enum value, response status, or endpoint behavior that existing clients rely on.
- MUST NOT repurpose an existing field with a new meaning.
- MUST NOT narrow accepted inputs in a way that breaks valid existing clients.
- SHOULD add new optional fields and new optional response metadata in a backward-compatible way.
- SHOULD add new endpoints rather than change stable endpoint semantics.

## Breaking Change Rules
A change is breaking if it does any of the following:
- removes or renames a path, field, query parameter, or header
- changes field type or enum meaning
- changes auth requirements in a way that blocks existing clients
- changes status codes or error shape for existing successful or failure paths
- changes pagination or sorting semantics incompatibly
- tightens validation so previously valid requests fail

- Breaking changes MUST ship only in a new major version.
- New major versions MUST use a new path prefix such as `/v2`.

## Deprecation
- MUST deprecate before removal unless an immediate security or legal issue requires otherwise.
- MUST document the deprecation date, replacement, and removal target.
- SHOULD emit a deprecation signal such as the `Deprecation` header for deprecated endpoints.
- SHOULD emit a `Sunset` header when a removal date is known.
- SHOULD link migration guidance from docs and changelogs.

## Coexistence and Migration
- MUST support at least one migration path from the prior major version.
- SHOULD run adjacent major versions in parallel during migration.
- MUST keep behavior consistent within each version.
- MUST keep docs and OpenAPI artifacts versioned with the implementation.

## Defaulting Rules
- When unsure, the agent MUST preserve compatibility instead of “cleaning up” an existing contract.
- When a desired change is ambiguous, the agent MUST prefer additive change over in-place mutation.
