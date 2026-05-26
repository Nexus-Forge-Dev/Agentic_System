# Backend API Layer Testing Checklist
# .agents/skills/qa-pro-max/checklists/backend.md
#
# Used by: sdet, qa-automation-engineer, backend-architect
# Activated by: /tdd, /e2e, /contract, /review

---

## HTTP SEMANTICS (every endpoint, every method)

```
□ Correct 2xx status code per success variant:
    GET    → 200 (with body) or 204 (no body)
    POST   → 201 (resource created) with Location header
    PUT    → 200 (updated) or 204 (no content)
    PATCH  → 200 (updated) or 204 (no content)
    DELETE → 200 (with body) or 204 (no body)
    NOT:   → generic 200 for all success cases

□ 400 Bad Request: invalid input schema (malformed JSON, wrong type)
□ 401 Unauthorized: missing token, invalid token, expired token
□ 403 Forbidden: valid token, insufficient role or tenant mismatch
□ 404 Not Found: resource does not exist (not 200 with null body)
□ 409 Conflict: duplicate resource, optimistic lock failure, state conflict
□ 422 Unprocessable Entity: schema valid but business rule violated
□ 429 Too Many Requests: rate limit hit — Retry-After header present
□ 500 Internal Server Error: NEVER includes stack traces or internal details
□ 503 Service Unavailable: dependency down — Retry-After header present
```

---

## INPUT VALIDATION (API boundary assertions)

```
□ Empty body → 400, not 500
□ Null body → 400, not 500
□ Extra unknown fields: stripped (if lenient) or rejected with 400 (if strict) — project decides
□ String length boundaries:
    max-1 characters → accepted
    max characters   → accepted
    max+1 characters → 400 rejected
□ Required field missing → 400 with field name in error message
□ Wrong type (string where integer expected) → 400
□ Null vs undefined vs omitted: each handled explicitly per spec
□ Injection strings in string fields:
    SQL: ' OR '1'='1; DROP TABLE users; --
    HTML/XSS: <script>alert(1)</script>
    Path traversal: ../../etc/passwd
□ Integer overflow values on numeric fields
□ Timestamps: past dates ✅ | future dates ✅ | invalid formats → 400 | timezone edge cases ✅
□ Array inputs: empty array ✅ | single item ✅ | max items ✅ | max+1 items → 400
□ UUID fields: invalid UUID format → 400 (not 404 or 500)
```

---

## API CONTRACT COMPLIANCE

```
□ Response body matches OpenAPI spec exactly:
    All documented fields present
    No undocumented fields in response
    Field types match spec (string not number, array not object)
□ Request body validated bidirectionally against OpenAPI schema
□ Required response headers present: Content-Type | X-Request-ID | Cache-Control
□ Content-Type: application/json for JSON responses (not text/html)
□ Pagination contract:
    page and limit parameters accepted and respected
    Total count returned in response or headers
    Last page edge case: returns empty array, not 404
    page=0 behavior: defined and consistent
□ Sorting contract:
    All documented sort fields work
    Invalid sort field → 400 with field name
    Sort direction: asc/desc both work
□ Filtering contract: all documented filters work, unknown filters handled
```

---

## AUTH BOUNDARY TESTING (mandatory for every protected route)

```
□ No token → 401 (not 403, not 500, not 200)
□ Malformed token → 401
□ Expired token → 401 with specific error indicating expiry
□ Tampered token (modified signature) → 401
□ Token for wrong environment (staging token on production) → 401
□ Insufficient role → 403 (not 401)
□ Correct role, wrong tenant → 403 (tenant isolation)
□ Cross-tenant data access attempt:
    User from Tenant A trying to read Tenant B's resource → 403
    User from Tenant A trying to modify Tenant B's resource → 403
□ Soft-deleted user token → 401 (not 200)
□ Revoked token (post-logout) → 401
```

---

## IDEMPOTENCY

```
□ POST with idempotency key:
    First request → 201 Created
    Duplicate request → same 201 (or 200) with same body
    No duplicate DB record created
□ PUT/PATCH idempotency:
    Applying same update twice → identical result, no error
    Concurrent identical PATCHes → exactly one wins, no corruption
□ DELETE idempotency:
    First DELETE → 200 or 204
    Second DELETE → 404 (not 500)
□ Webhook delivery: duplicate webhook → processed once (idempotency key checked)
```

---

## RESPONSE QUALITY

```
□ All error responses conform to RFC 7807 Problem Details:
    {
      "type": "https://...",
      "title": "Human-readable summary",
      "status": 400,
      "detail": "Specific detail about this occurrence",
      "instance": "/specific/resource/path"
    }
□ No stack traces in ANY environment (not just production)
□ No internal service URLs, hostnames, or ports in response bodies
□ No database column names, table names, or query strings in error messages
□ No internal user IDs or system identifiers in client-facing error messages
□ Request ID propagated: X-Request-ID present and traceable in logs
```

---

## RATE LIMITING BEHAVIOR

```
□ Auth endpoints: rate limited (login, password reset, token refresh)
□ Rate limit response: 429 status with Retry-After header (seconds value)
□ Rate limit resets correctly after window expires
□ Distributed rate limiting: limit applies across multiple service instances
□ Rate limit headers present on successful responses: X-RateLimit-Limit | X-RateLimit-Remaining
```

---

## SERVICE LAYER (unit testing)

```
□ All public service functions have unit tests
□ No direct DB queries in route handlers — service layer enforced
□ Service functions tested in isolation (DB mocked, external calls mocked)
□ Business logic boundary conditions tested:
    Minimum valid inputs
    Maximum valid inputs
    Invalid state transitions
□ Error propagation: service errors surface as correct HTTP status at route layer
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never assert only on status code — always assert response body shape
❌ Never skip auth boundary tests — mandatory for every protected route
❌ Never use real third-party API credentials in test runs
❌ Never test with superuser DB credentials through the application layer
❌ Never assert that a field "exists" — assert its exact value
❌ Never use placeholder strings like "test" or "example" in test data
❌ Never leave test-created resources in the database without teardown
```
