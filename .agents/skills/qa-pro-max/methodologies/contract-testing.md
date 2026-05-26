# Contract Testing Methodology
# .agents/skills/qa-pro-max/methodologies/contract-testing.md
#
# Used by: sdet, qa-automation-engineer
# Activated by: /contract command

---

## WHY CONTRACT TESTING

Integration tests verify that components work together.
Contract tests verify that the AGREEMENT between components doesn't drift.

Without contract tests:
  → Provider adds a new required field
  → Consumer still sends old payload
  → Integration test passes (mocked provider)
  → Production breaks

Contract tests catch schema drift BEFORE integration — at the boundary.

---

## THE TWO SIDES OF A CONTRACT

```
CONSUMER: The service that makes the API call (frontend, another microservice)
PROVIDER: The service that owns the API endpoint (backend, third-party)

Consumer-Driven Contracts (preferred approach):
  → Consumer defines what it expects from the provider
  → Provider verifies it can satisfy the consumer's expectations
  → Consumer owns the spec — provider must not break it
```

---

## WHAT CONTRACTS COVER

```
REQUEST CONTRACT (consumer → provider):
  □ HTTP method (GET, POST, PUT, PATCH, DELETE)
  □ URL path and path parameters
  □ Required query parameters
  □ Required headers (Authorization, Content-Type, X-Tenant-ID)
  □ Request body schema:
      Required fields: present, correct type
      Optional fields: handled if absent
      Unknown fields: stripped or rejected per spec
  □ Idempotency key format (if applicable)

RESPONSE CONTRACT (provider → consumer):
  □ HTTP status code per scenario (2xx, 4xx, 5xx)
  □ Required response headers (Content-Type, X-Request-ID)
  □ Response body schema:
      Required fields: always present, correct type
      Optional fields: absent when N/A, never null unless nullable in spec
      No undocumented fields
  □ Error response schema: conforms to RFC 7807 Problem Details
  □ Pagination envelope (if applicable): total, page, limit fields
```

---

## SCHEMA DRIFT DETECTION

Schema drift = when implementation diverges from the documented spec.

Drift categories:
```
BREAKING (blocks merge):
  → Field removed from response that consumer requires
  → Field type changed (string → integer)
  → Required request field added without backward compatibility
  → HTTP status code changed for an existing scenario
  → Authentication scheme changed

NON-BREAKING (warning only):
  → New optional response field added (consumers should ignore unknown fields)
  → New optional request field added
  → New endpoint added
  → Response fields reordered (if consumer uses key-based access, not index)

How to detect:
  1. Run OpenAPI validator against live API responses
  2. Compare generated schema against committed spec
  3. Diff the spec file in every PR (spec change = contract change = review required)
```

---

## CONTRACT TEST STRUCTURE

```
For each API endpoint, write a contract test that covers:

SCENARIO 1: Happy path request → successful response
  Arrange: valid request payload matching consumer's real usage
  Act: call the endpoint
  Assert:
    - Status code matches spec
    - Response body matches schema exactly (no extra fields, all required fields present)
    - Types match (string not number, array not object)
    - Required headers present

SCENARIO 2: Invalid request → error response
  Arrange: malformed/missing required field
  Act: call the endpoint
  Assert:
    - Status code = 400
    - Response body is RFC 7807 Problem Details format
    - Error references the invalid field

SCENARIO 3: Unauthorized request → 401
  Arrange: missing or expired token
  Act: call the endpoint
  Assert:
    - Status code = 401
    - Response body does not contain resource data

SCENARIO 4: Not found → 404 (if applicable)
  Arrange: non-existent resource ID
  Act: call the endpoint
  Assert:
    - Status code = 404
    - Response body is RFC 7807 Problem Details format
```

---

## OPENAPI SPEC STANDARDS

```
□ OpenAPI 3.1 (or 3.0.x) — not Swagger 2.0
□ All endpoints documented (no undocumented routes)
□ All request bodies have schema defined
□ All response bodies have schema defined for: 200, 201, 204, 400, 401, 403, 404, 422, 429, 500
□ All schemas have required fields explicitly listed
□ Nullable fields explicitly marked with nullable: true (OAS 3.0) or type: [string, null] (OAS 3.1)
□ Examples provided for complex request/response bodies
□ Tags used to group endpoints by resource type
□ Spec file committed to repo alongside implementation code
□ Spec change requires a PR review from at least one consumer team representative
```

---

## VERSION MANAGEMENT

```
Breaking changes require a version bump:
  Current: /api/v1/users
  After breaking change: /api/v2/users

Backward compatibility period:
  Old version remains functional for a defined deprecation period
  Deprecation header added: Deprecation: true, Sunset: <date>
  Consumer teams notified before sunset date

Non-breaking additions:
  Added under same version (v1 can add optional fields)
  Consumer code must gracefully handle unknown fields
    → Never fail on unexpected keys in response
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never write contract tests against a mocked provider — test against real implementation
❌ Never commit OpenAPI spec changes without running contract test suite
❌ Never add required fields to an existing endpoint without bumping version
❌ Never let spec drift accumulate — every PR that changes API must update spec
❌ Never use any as the type for API fields in TypeScript schemas
❌ Never omit error response schemas from the OpenAPI spec
```
