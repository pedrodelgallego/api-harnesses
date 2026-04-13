# Changelog

## 0.1.0

- Initial release.
- Violations table: 8 violations (7 ERROR, 1 SHOULD NOT) covering inverted test pyramid, real network calls in unit/component tests, hardcoded base URLs/credentials/IDs, happy-path-only coverage, contract tests used for stateful scenarios, shared mutable state between tests, `/* v8 ignore */` on reachable branches, and coverage below 100% without a documented exemption.
- Sections: Test Pyramid, Assertions, Component Tests, Coverage Suppression (`/* v8 ignore */`), Contract Testing, Test Data, Organisation & Debuggability.
