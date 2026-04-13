# Changelog

## 0.1.0

- Initial release.
- Violations table: 9 violations (all ERROR) covering missing HSTS, missing `X-Content-Type-Options`, missing frame protection, missing or unsafe CSP, missing `Referrer-Policy`, wildcard CORS on authenticated endpoints, unconditional `Origin` reflection, `Server`/`X-Powered-By` exposure, and missing `Cache-Control: no-store` on sensitive responses.
- Sections: Required Headers, Cache Control, Server Fingerprinting, CORS (allowlist, exposed headers, allowed headers).
